import Foundation
import BigInt
import SubstrateSdk

private typealias OrmlParsingResult = (
    callPath: CallCodingPath,
    isAccountMatched: Bool,
    callAccountId: AccountId?,
    callCurrencyId: JSON,
    callAmount: BigUInt
)

private typealias AssetsParsingResult = (
    callPath: CallCodingPath,
    isAccountMatched: Bool,
    callAccountId: AccountId?,
    callAssetId: String,
    callAmount: BigUInt
)

private typealias BalancesParsingResult = (
    callPath: CallCodingPath,
    isAccountMatched: Bool,
    callAccountId: AccountId?,
    callAmount: BigUInt
)

extension ExtrinsicProcessor {
    func matchStatus(
        for index: UInt32,
        eventRecords: [EventRecord],
        metadata: RuntimeMetadataProtocol
    ) -> Bool? {
        eventRecords.filter { record in
            guard record.extrinsicIndex == index,
                  let eventPath = metadata.createEventCodingPath(from: record.event) else {
                return false
            }

            return [.extrisicSuccess, .extrinsicFailed].contains(eventPath)
        }.first.map { metadata.createEventCodingPath(from: $0.event) == .extrisicSuccess }
    }

    func matchOrmlTransfer(
        extrinsicIndex: UInt32,
        extrinsic: Extrinsic,
        eventRecords: [EventRecord],
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> ExtrinsicProcessingResult? {
        do {
            let metadata = codingFactory.metadata
            let context = codingFactory.createRuntimeJsonContext()

            let maybeSender: AccountId? = try extrinsic.signature?.address.map(
                to: MultiAddress.self,
                with: context.toRawContext()
            ).accountId

            let result = try parseOrmlExtrinsic(extrinsic, sender: maybeSender, context: context)

            guard result.callPath.isTokensTransfer, result.isAccountMatched, let sender = maybeSender else {
                return nil
            }

            let optStatus = matchStatus(for: extrinsicIndex, eventRecords: eventRecords, metadata: metadata)

            guard let status = optStatus else {
                return nil
            }

            let fee = findFee(
                for: extrinsicIndex,
                sender: sender,
                eventRecords: eventRecords,
                metadata: metadata,
                runtimeJsonContext: context
            )

            let peerId = accountId == sender ? result.callAccountId : sender

            guard
                let asset = findOrmlAssetMatching(
                    result: result,
                    assets: chain.assets,
                    codingFactory: codingFactory
                ) else {
                return nil
            }

            return ExtrinsicProcessingResult(
                sender: sender,
                callPath: result.callPath,
                call: extrinsic.call,
                extrinsicHash: nil,
                fee: fee,
                peerId: peerId,
                amount: result.callAmount,
                isSuccess: status,
                assetId: asset.assetId
            )

        } catch {
            return nil
        }
    }

    private func findOrmlAssetMatching(
        result: OrmlParsingResult,
        assets: Set<AssetModel>,
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> AssetModel? {
        assets.first { asset in
            guard
                asset.type == AssetType.orml.rawValue,
                let typeExtra = try? asset.typeExtras?.map(to: OrmlTokenExtras.self) else {
                return false
            }

            do {
                let encoder = codingFactory.createEncoder()
                try encoder.append(json: result.callCurrencyId, type: typeExtra.currencyIdType)
                let currencyIdScale = try encoder.encode()
                let assetCurrencyId = try Data(hexString: typeExtra.currencyIdScale)

                return currencyIdScale == assetCurrencyId
            } catch {
                return false
            }
        }
    }

    private func parseOrmlExtrinsic(
        _ extrinsic: Extrinsic,
        sender: AccountId?,
        context: RuntimeJsonContext
    ) throws -> OrmlParsingResult {
        let call = try extrinsic.call.map(
            to: RuntimeCall<OrmlTokenTransfer>.self,
            with: context.toRawContext()
        )
        let callAccountId = call.args.dest.accountId
        let callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)
        let isAccountMatched = accountId == sender || accountId == callAccountId
        let currencyId = call.args.currencyId

        return (callPath, isAccountMatched, callAccountId, currencyId, call.args.amount)
    }

    private func parseEthereumTransact(
        extrinsicIndex: UInt32,
        extrinsic: Extrinsic,
        eventRecords: [EventRecord],
        metadata: RuntimeMetadataProtocol,
        runtimeJsonContext: RuntimeJsonContext
    ) -> ExtrinsicProcessingResult? {
        let optExecutedEvent = eventRecords.first { record in
            if
                record.extrinsicIndex == extrinsicIndex,
                let eventPath = metadata.createEventCodingPath(from: record.event),
                eventPath == EventCodingPath.ethereumExecuted {
                return true
            } else {
                return false
            }
        }

        guard let executedEvent = optExecutedEvent?.event else {
            return nil
        }

        do {
            let executedValue = try executedEvent.params.map(
                to: EthereumExecuted.self,
                with: runtimeJsonContext.toRawContext()
            )

            guard executedValue.from == accountId else {
                return nil
            }

            guard let assetId = chain.utilityAssets().first?.assetId ?? chain.assets.first?.assetId else {
                return nil
            }

            let fee = findFee(
                for: extrinsicIndex,
                sender: executedValue.from,
                eventRecords: eventRecords,
                metadata: metadata,
                runtimeJsonContext: runtimeJsonContext
            )

            return ExtrinsicProcessingResult(
                sender: executedValue.from,
                callPath: CallCodingPath.ethereumTransact,
                call: extrinsic.call,
                extrinsicHash: executedValue.transactionHash,
                fee: fee,
                peerId: executedValue.to,
                amount: nil,
                isSuccess: executedValue.isSuccess,
                assetId: assetId
            )
        } catch {
            return nil
        }
    }

    private func parseSubstrateExtrinsic(
        extrinsicIndex: UInt32,
        extrinsic: Extrinsic,
        eventRecords: [EventRecord],
        metadata: RuntimeMetadataProtocol,
        runtimeJsonContext: RuntimeJsonContext
    ) -> ExtrinsicProcessingResult? {
        do {
            let maybeSender: AccountId? = try extrinsic.signature?.address.map(
                to: MultiAddress.self,
                with: runtimeJsonContext.toRawContext()
            ).accountId

            let call = try extrinsic.call.map(to: RuntimeCall<NoRuntimeArgs>.self)
            let callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)
            let isAccountMatched = accountId == maybeSender

            guard
                let sender = maybeSender,
                isAccountMatched,
                let isSuccess = matchStatus(
                    for: extrinsicIndex,
                    eventRecords: eventRecords,
                    metadata: metadata
                ) else {
                return nil
            }

            let fee = findFee(
                for: extrinsicIndex,
                sender: sender,
                eventRecords: eventRecords,
                metadata: metadata,
                runtimeJsonContext: runtimeJsonContext
            )

            guard let assetId = chain.utilityAssets().first?.assetId ?? chain.assets.first?.assetId else {
                return nil
            }

            return ExtrinsicProcessingResult(
                sender: sender,
                callPath: callPath,
                call: extrinsic.call,
                extrinsicHash: nil,
                fee: fee,
                peerId: nil,
                amount: nil,
                isSuccess: isSuccess,
                assetId: assetId
            )

        } catch {
            return nil
        }
    }

    func matchAssetsTransfer(
        extrinsicIndex: UInt32,
        extrinsic: Extrinsic,
        eventRecords: [EventRecord],
        metadata: RuntimeMetadataProtocol,
        context: RuntimeJsonContext
    ) -> ExtrinsicProcessingResult? {
        do {
            let rawContext = context.toRawContext()
            let maybeAddress = extrinsic.signature?.address
            let maybeSender = try maybeAddress?.map(to: MultiAddress.self, with: rawContext).accountId

            let result = try parseAssetsExtrinsic(extrinsic, sender: maybeSender, context: context)

            guard
                result.callPath.isAssetsTransfer,
                result.isAccountMatched,
                let sender = maybeSender else {
                return nil
            }

            let status = matchStatus(for: extrinsicIndex, eventRecords: eventRecords, metadata: metadata)

            guard let isSuccess = status else {
                return nil
            }

            let fee = findFee(
                for: extrinsicIndex,
                sender: sender,
                eventRecords: eventRecords,
                metadata: metadata,
                runtimeJsonContext: context
            )

            let peerId = accountId == sender ? result.callAccountId : sender

            let maybeAsset = chain.assets.first { asset in
                guard
                    asset.type == AssetType.statemine.rawValue,
                    let typeExtra = try? asset.typeExtras?.map(to: StatemineAssetExtras.self) else {
                    return false
                }

                return typeExtra.assetId == result.callAssetId
            }

            guard let asset = maybeAsset else {
                return nil
            }

            return ExtrinsicProcessingResult(
                sender: sender,
                callPath: result.callPath,
                call: extrinsic.call,
                extrinsicHash: nil,
                fee: fee,
                peerId: peerId,
                amount: result.callAmount,
                isSuccess: isSuccess,
                assetId: asset.assetId
            )

        } catch {
            return nil
        }
    }

    private func parseAssetsExtrinsic(
        _ extrinsic: Extrinsic,
        sender: AccountId?,
        context: RuntimeJsonContext
    ) throws -> AssetsParsingResult {
        let call = try extrinsic.call.map(
            to: RuntimeCall<AssetsTransfer>.self,
            with: context.toRawContext()
        )
        let callAccountId = call.args.target.accountId
        let callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)
        let isAccountMatched = accountId == sender || accountId == callAccountId
        let assetId = call.args.assetId

        return (callPath, isAccountMatched, callAccountId, assetId, call.args.amount)
    }

    func matchBalancesTransfer(
        extrinsicIndex: UInt32,
        extrinsic: Extrinsic,
        eventRecords: [EventRecord],
        metadata: RuntimeMetadataProtocol,
        context: RuntimeJsonContext
    ) -> ExtrinsicProcessingResult? {
        do {
            let maybeSender: AccountId? = try extrinsic.signature?.address.map(
                to: MultiAddress.self,
                with: context.toRawContext()
            ).accountId

            let result = try parseBalancesExtrinsic(extrinsic, sender: maybeSender, context: context)

            guard
                result.callPath.isBalancesTransfer,
                result.isAccountMatched,
                let sender = maybeSender,
                let isSuccess = matchStatus(
                    for: extrinsicIndex,
                    eventRecords: eventRecords,
                    metadata: metadata
                ) else {
                return nil
            }

            let fee = findFee(
                for: extrinsicIndex,
                sender: sender,
                eventRecords: eventRecords,
                metadata: metadata,
                runtimeJsonContext: context
            )

            let peerId = accountId == sender ? result.callAccountId : sender

            guard let assetId = chain.utilityAssets().first?.assetId ?? chain.assets.first?.assetId else {
                return nil
            }

            return ExtrinsicProcessingResult(
                sender: sender,
                callPath: result.callPath,
                call: extrinsic.call,
                extrinsicHash: nil,
                fee: fee,
                peerId: peerId,
                amount: result.callAmount,
                isSuccess: isSuccess,
                assetId: assetId
            )

        } catch {
            return nil
        }
    }

    private func parseBalancesExtrinsic(
        _ extrinsic: Extrinsic,
        sender: AccountId?,
        context: RuntimeJsonContext
    ) throws -> BalancesParsingResult {
        let call = try extrinsic.call.map(
            to: RuntimeCall<TransferCall>.self,
            with: context.toRawContext()
        )
        let callAccountId = call.args.dest.accountId
        let callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)
        let isAccountMatched = accountId == sender || accountId == callAccountId

        return (callPath, isAccountMatched, callAccountId, call.args.value)
    }

    func matchExtrinsic(
        extrinsicIndex: UInt32,
        extrinsic: Extrinsic,
        eventRecords: [EventRecord],
        metadata: RuntimeMetadataProtocol,
        runtimeJsonContext: RuntimeJsonContext
    ) -> ExtrinsicProcessingResult? {
        let ethereumCall = CallCodingPath.ethereumTransact

        if chain.isEthereumBased,
           extrinsic.call.moduleName?.stringValue == ethereumCall.moduleName,
           extrinsic.call.callName?.stringValue == ethereumCall.callName {
            return parseEthereumTransact(
                extrinsicIndex: extrinsicIndex,
                extrinsic: extrinsic,
                eventRecords: eventRecords,
                metadata: metadata,
                runtimeJsonContext: runtimeJsonContext
            )
        } else {
            return parseSubstrateExtrinsic(
                extrinsicIndex: extrinsicIndex,
                extrinsic: extrinsic,
                eventRecords: eventRecords,
                metadata: metadata,
                runtimeJsonContext: runtimeJsonContext
            )
        }
    }
}
