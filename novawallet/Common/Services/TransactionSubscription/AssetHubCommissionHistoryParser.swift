import Foundation
import SubstrateSdk

enum AssetHubCommissionHistoryError: Error {
    case ambiguousCandidates
    case undeterminedWrapperOutcome
    case unrecognizedCommissionedCall
    case unsupportedOutputAsset
    case predictedOutputUnderflow
}

struct AssetHubCommissionedSwapCall {
    let receiver: AccountId
    let assetIn: ChainAssetId
    let assetOut: ChainAssetId
    let amountInBound: Balance
    let amountOutBound: Balance
    let path: [AssetConversionPallet.AssetId]
    let bounds: AssetConversionSwapBounds
    let commission: AssetConversionSwapVerification.Commission

    var verification: AssetConversionSwapVerification {
        .init(receiver: receiver, path: path, bounds: bounds, commission: commission)
    }
}

struct AssetHubCommissionHistoryParser {
    struct Swap {
        let call: AnyRuntimeCall
        let sender: AccountId
        let receiver: AccountId
        let assetIn: AssetModel.Id
        let amountIn: Balance
        let assetOut: AssetModel.Id
        let netAmountOut: Balance
        let isSuccess: Bool
    }

    enum Outcome {
        case notCommissioned
        case recognizedButUnresolved(Error)
        case swap(Swap)
    }

    let logger: LoggerProtocol

    init(logger: LoggerProtocol = Logger.shared) {
        self.logger = logger
    }

    func parse(
        extrinsic: Extrinsic,
        sender: AccountId,
        account: AccountId,
        events: [Event],
        extrinsicSucceeded: Bool,
        chain: ChainModel,
        codingFactory: RuntimeCoderFactoryProtocol,
        beneficiaries: Set<AccountId>
    ) -> Outcome {
        guard !beneficiaries.isEmpty else {
            return .notCommissioned
        }

        let candidates = AssetHubCommissionTopology.findBatches(
            in: extrinsic.call,
            extrinsicSender: sender,
            supportedAssetsPallets: PalletAssets.palletNames(for: chain),
            context: codingFactory.createRuntimeJsonContext()
        )

        var prepared: [(batch: AssetHubCommissionedBatch, call: AssetHubCommissionedSwapCall)] = []
        var ownedFailure: Error?

        for candidate in candidates where candidate.effectiveSender == account {
            do {
                if let call = try decodeCommissionedCall(
                    for: candidate,
                    chain: chain,
                    codingFactory: codingFactory,
                    beneficiaries: beneficiaries
                ) {
                    prepared.append((candidate, call))
                }
            } catch {
                ownedFailure = error
            }
        }

        if let ownedFailure {
            return .recognizedButUnresolved(ownedFailure)
        }

        guard !prepared.isEmpty else {
            return .notCommissioned
        }

        guard
            prepared.count == 1,
            let candidate = prepared.first,
            !candidate.batch.hasUtilityAncestor else {
            return .recognizedButUnresolved(AssetHubCommissionHistoryError.ambiguousCandidates)
        }

        do {
            let optIsSuccess: Bool? = extrinsicSucceeded
                ? try checkWrappersSucceeded(candidate.batch.wrappers, events: events, codingFactory: codingFactory)
                : false

            guard let isSuccess = optIsSuccess else {
                return .recognizedButUnresolved(AssetHubCommissionHistoryError.undeterminedWrapperOutcome)
            }

            return .swap(
                try createSwap(
                    for: candidate.batch,
                    call: candidate.call,
                    events: events,
                    isSuccess: isSuccess,
                    codingFactory: codingFactory
                )
            )
        } catch {
            return .recognizedButUnresolved(error)
        }
    }
}

private extension AssetHubCommissionHistoryParser {
    func createSwap(
        for batch: AssetHubCommissionedBatch,
        call: AssetHubCommissionedSwapCall,
        events: [Event],
        isSuccess: Bool,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> Swap {
        let commission = call.commission

        let amountIn: Balance
        let netAmountOut: Balance

        if isSuccess {
            let measurement = try AssetConversionEventParser(logger: logger).measure(
                from: events,
                verification: call.verification,
                origin: batch.effectiveSender,
                using: codingFactory
            )

            netAmountOut = measurement.netAmountOut
            amountIn = measurement.amountIn
        } else {
            guard call.amountOutBound >= commission.amount else {
                throw AssetHubCommissionHistoryError.predictedOutputUnderflow
            }

            netAmountOut = call.amountOutBound - commission.amount
            amountIn = call.amountInBound
        }

        return Swap(
            call: batch.swapCall,
            sender: batch.effectiveSender,
            receiver: call.receiver,
            assetIn: call.assetIn.assetId,
            amountIn: amountIn,
            assetOut: call.assetOut.assetId,
            netAmountOut: netAmountOut,
            isSuccess: isSuccess
        )
    }

    func decodeCommissionedCall(
        for batch: AssetHubCommissionedBatch,
        chain: ChainModel,
        codingFactory: RuntimeCoderFactoryProtocol,
        beneficiaries: Set<AccountId>
    ) throws -> AssetHubCommissionedSwapCall? {
        let context = codingFactory.createRuntimeJsonContext()

        guard
            let collection = try? decodeCollectionCall(batch.commissionCall, context: context),
            beneficiaries.contains(collection.beneficiary) else {
            return nil
        }

        guard let swap = try AssetConversionSwapCallDecoder.decode(batch.swapCall, context: context) else {
            throw AssetHubCommissionHistoryError.unrecognizedCommissionedCall
        }

        guard
            swap.receiver == batch.effectiveSender,
            collection.amount > 0,
            let remoteAssetIn = swap.path.first,
            let remoteAssetOut = swap.path.last else {
            throw AssetHubCommissionHistoryError.unrecognizedCommissionedCall
        }

        let conversionClosure = AssetHubTokensConverter.createPoolAssetToLocalClosure(
            for: chain,
            codingFactory: codingFactory
        )

        guard
            let assetIn = AssetHubTokensConverter.convertFromMultilocationToLocal(
                remoteAssetIn,
                chain: chain,
                conversionClosure: conversionClosure
            ),
            let assetOut = AssetHubTokensConverter.convertFromMultilocationToLocal(
                remoteAssetOut,
                chain: chain,
                conversionClosure: conversionClosure
            ) else {
            throw AssetHubCommissionHistoryError.unsupportedOutputAsset
        }

        let storageInfo = try AssetStorageInfo.extract(from: assetOut.asset, codingFactory: codingFactory)

        try validate(collection: collection, call: batch.commissionCall, storageInfo: storageInfo)

        return AssetHubCommissionedSwapCall(
            receiver: swap.receiver,
            assetIn: assetIn.chainAssetId,
            assetOut: assetOut.chainAssetId,
            amountInBound: swap.amountIn,
            amountOutBound: swap.amountOut,
            path: swap.path,
            bounds: .init(swap: swap.call),
            commission: .init(
                amount: collection.amount,
                beneficiary: collection.beneficiary,
                assetStorageInfo: storageInfo
            )
        )
    }

    func checkWrappersSucceeded(
        _ wrappers: [AssetHubDispatchWrapper],
        events: [Event],
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> Bool? {
        var markers = events.filter {
            codingFactory.metadata.eventMatches($0, path: Proxy.executedEventPath) ||
                codingFactory.metadata.eventMatches($0, path: MultisigPallet.multisigExecutedEventPath)
        }

        let expectedProxies = wrappers.filter {
            if case .proxy = $0 { return true } else { return false }
        }.count
        let actualProxies = markers.filter {
            codingFactory.metadata.eventMatches($0, path: Proxy.executedEventPath)
        }.count
        guard actualProxies <= expectedProxies,
              markers.count - actualProxies <= wrappers.count - expectedProxies else { return nil }

        for wrapper in wrappers {
            let isInline: Bool
            if case .multisig(threshold: 1, approver: _, origin: _, call: _) = wrapper {
                isInline = true
            } else {
                isInline = false
            }

            guard let marker = markers.last else {
                if isInline { continue }
                return nil
            }

            guard let succeeded = try checkWrapperSucceeded(wrapper, marker: marker, codingFactory: codingFactory) else {
                if isInline { continue }
                return nil
            }

            markers.removeLast()
            if !succeeded { return false }
        }

        return markers.isEmpty ? true : nil
    }

    func checkWrapperSucceeded(
        _ wrapper: AssetHubDispatchWrapper,
        marker: Event,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> Bool? {
        let context = codingFactory.createRuntimeJsonContext()
        switch wrapper {
        case .proxy:
            guard codingFactory.metadata.eventMatches(marker, path: Proxy.executedEventPath) else { return nil }
            let event: Proxy.ExecutedEvent = try ExtrinsicExtraction.getEventParams(from: marker, context: context)
            return event.result.isOk
        case let .multisig(_, approver, origin, call):
            guard codingFactory.metadata.eventMatches(
                marker, path: MultisigPallet.multisigExecutedEventPath
            ) else { return nil }
            let event: MultisigPallet.MultisigExecutedEvent = try ExtrinsicExtraction.getEventParams(
                from: marker, context: context
            )
            let encoder = codingFactory.createEncoder()
            try encoder.append(json: call, type: GenericType.call.name)
            let callHash = try encoder.encode().blake2b32()
            guard event.approvingAccountId == approver, event.accountId == origin,
                  event.callHash == callHash else { return nil }
            return event.result.isOk
        }
    }
}
