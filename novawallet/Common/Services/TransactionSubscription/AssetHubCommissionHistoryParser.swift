import Foundation
import SubstrateSdk

enum AssetHubCommissionHistoryError: Error {
    case ambiguousCandidates
    case undeterminedWrapperOutcome
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

        var prepared: [(batch: AssetHubCommissionedBatch, params: AssetHubExchangeSwapParams)] = []
        var ownedFailure: Error?

        for candidate in candidates where candidate.effectiveSender == account {
            do {
                if let params = try createParams(
                    for: candidate,
                    chain: chain,
                    codingFactory: codingFactory,
                    beneficiaries: beneficiaries
                ) {
                    prepared.append((candidate, params))
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
                    params: candidate.params,
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
        params: AssetHubExchangeSwapParams,
        events: [Event],
        isSuccess: Bool,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> Swap {
        guard let commission = params.commission else {
            throw AssetHubExchangePreparationError.invalidCommission
        }

        let amountIn: Balance
        let netAmountOut: Balance

        if isSuccess {
            netAmountOut = try AssetConversionEventParser(logger: logger).extractDeposit(
                from: events,
                params: params,
                origin: batch.effectiveSender,
                using: codingFactory
            )

            amountIn = try findMeasuredAmountIn(
                in: events,
                params: params,
                origin: batch.effectiveSender,
                codingFactory: codingFactory
            )
        } else {
            guard params.callArgs.amountOut >= commission.amount else {
                throw AssetHubExchangeEventError.outputUnderflow
            }

            netAmountOut = params.callArgs.amountOut - commission.amount
            amountIn = params.callArgs.amountIn
        }

        return Swap(
            call: batch.swapCall,
            sender: batch.effectiveSender,
            receiver: params.callArgs.receiver,
            assetIn: params.callArgs.assetIn.assetId,
            amountIn: amountIn,
            assetOut: params.callArgs.assetOut.assetId,
            netAmountOut: netAmountOut,
            isSuccess: isSuccess
        )
    }

    func findMeasuredAmountIn(
        in events: [Event],
        params: AssetHubExchangeSwapParams,
        origin: AccountId,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> Balance {
        let context = codingFactory.createRuntimeJsonContext()

        let swaps: [AssetConversionPallet.SwapExecutedEvent] = try events.compactMap { event in
            guard
                codingFactory.metadata.eventMatches(
                    event,
                    path: AssetConversionPallet.swapExecutedEvent
                ) else {
                return nil
            }

            let swap: AssetConversionPallet.SwapExecutedEvent = try ExtrinsicExtraction.getEventParams(
                from: event,
                context: context
            )

            guard
                swap.who == origin,
                swap.sendTo == params.callArgs.receiver,
                swap.path.map(\.asset) == params.path else {
                return nil
            }

            switch params.swap {
            case let .exactIn(call):
                return swap.amountIn == call.amountIn && swap.amountOut >= call.amountOutMin ? swap : nil
            case let .exactOut(call):
                return swap.amountOut == call.amountOut && swap.amountIn <= call.amountInMax ? swap : nil
            }
        }

        guard swaps.count == 1, let measured = swaps.first else {
            throw AssetHubExchangeEventError.missingOrAmbiguousSwap
        }

        return measured.amountIn
    }

    func createParams(
        for batch: AssetHubCommissionedBatch,
        chain: ChainModel,
        codingFactory: RuntimeCoderFactoryProtocol,
        beneficiaries: Set<AccountId>
    ) throws -> AssetHubExchangeSwapParams? {
        let context = codingFactory.createRuntimeJsonContext()

        guard
            let swap = (try? decodeSwapCall(batch.swapCall, context: context)) ?? nil,
            let collection = try? decodeCollectionCall(batch.commissionCall, context: context),
            beneficiaries.contains(collection.beneficiary) else {
            return nil
        }

        guard
            swap.receiver == batch.effectiveSender,
            collection.amount > 0,
            let remoteAssetIn = swap.path.first,
            let remoteAssetOut = swap.path.last else {
            throw AssetHubExchangePreparationError.invalidCommission
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
            throw AssetHubExchangePreparationError.unsupportedStorage
        }

        let storageInfo = try AssetStorageInfo.extract(from: assetOut.asset, codingFactory: codingFactory)

        try validate(collection: collection, call: batch.commissionCall, storageInfo: storageInfo)

        return AssetHubExchangeSwapParams(
            callArgs: .init(
                assetIn: assetIn.chainAssetId,
                amountIn: swap.amountIn,
                assetOut: assetOut.chainAssetId,
                amountOut: swap.amountOut,
                receiver: swap.receiver,
                direction: swap.direction,
                slippage: BigRational(numerator: 0, denominator: 1)
            ),
            path: swap.path,
            swap: swap.call,
            commission: .init(
                amount: collection.amount,
                beneficiary: collection.beneficiary,
                assetStorageInfo: storageInfo
            ),
            codingFactory: codingFactory
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
