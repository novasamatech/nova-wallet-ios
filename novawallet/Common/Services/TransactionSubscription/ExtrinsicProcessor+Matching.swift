import Foundation
import BigInt
import SubstrateSdk

private typealias OrmlParsingResult = (
    callPath: CallCodingPath,
    isAccountMatched: Bool,
    callAccountId: AccountId?,
    callSenderId: AccountId,
    callCurrencyId: JSON,
    callAmount: BigUInt
)

private typealias AssetsParsingResult = (
    callPath: CallCodingPath,
    isAccountMatched: Bool,
    callAccountId: AccountId?,
    callSenderAccountId: AccountId,
    callAssetId: JSON,
    callAmount: BigUInt
)

private typealias BalancesParsingResult = (
    callPath: CallCodingPath,
    isAccountMatched: Bool,
    callAccountId: AccountId?,
    callSenderId: AccountId,
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

            return [
                SystemPallet.extrinsicSuccessEventPath,
                SystemPallet.extrinsicFailedEventPath
            ].contains(eventPath)
        }.first.map { metadata.createEventCodingPath(from: $0.event) == SystemPallet.extrinsicSuccessEventPath }
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

            let maybeSender: AccountId? = try extrinsic.getSignedExtrinsic()?.signature.address.map(
                to: MultiAddress.self,
                with: context.toRawContext()
            ).accountId

            guard let sender = maybeSender else {
                return nil
            }

            let eventRecords = eventRecords.filter { $0.extrinsicIndex == extrinsicIndex }
            let result = try parseOrmlExtrinsic(
                extrinsic,
                eventRecords: eventRecords,
                metadata: metadata,
                sender: sender,
                context: context
            )

            guard result.callPath.isTokensTransfer, result.isAccountMatched else {
                return nil
            }

            let optStatus = matchStatus(for: extrinsicIndex, eventRecords: eventRecords, metadata: metadata)

            guard let status = optStatus else {
                return nil
            }

            let hydraParsingParams = prepareHydraParsingParams(
                for: sender,
                codingFactory: codingFactory
            )

            let fee = try? findOrmlFee(
                for: hydraParsingParams,
                extrinsicIndex: extrinsicIndex,
                eventRecords: eventRecords,
                codingFactory: codingFactory
            )

            let peerId = accountId == result.callSenderId ? result.callAccountId : result.callSenderId

            guard
                let asset = findOrmlAssetMatching(
                    result: result,
                    assets: chain.assets,
                    codingFactory: codingFactory
                ) else {
                return nil
            }

            return ExtrinsicProcessingResult(
                sender: result.callSenderId,
                callPath: result.callPath,
                call: extrinsic.call,
                extrinsicHash: nil,
                fee: fee?.amount,
                feeAssetId: fee?.assetId,
                peerId: peerId,
                amount: result.callAmount,
                isSuccess: status,
                assetId: asset.assetId,
                swap: nil
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
        eventRecords: [EventRecord],
        metadata: RuntimeMetadataProtocol,
        sender: AccountId,
        context: RuntimeJsonContext
    ) throws -> OrmlParsingResult {
        let callMapper = NestedExtrinsicCallMapper(extrinsicSender: sender)
        let optResult: NestedExtrinsicCallMapResult<RuntimeCall<OrmlTokensPallet.TransferCall>>?
        optResult = try? callMapper.mapRuntimeCall(
            call: extrinsic.call,
            context: context
        )

        if let callResult = optResult {
            let call = try callResult.getFirstCallOrThrow()
            let callAccountId = call.args.dest.accountId
            let callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)
            let isAccountMatched = accountId == callResult.callSender || accountId == callAccountId
            let currencyId = call.args.currencyId

            return (callPath, isAccountMatched, callAccountId, callResult.callSender, currencyId, call.args.amount)
        } else {
            let callResult: NestedExtrinsicCallMapResult<RuntimeCall<OrmlTokensPallet.TransferAllCall>>
            callResult = try callMapper.mapRuntimeCall(
                call: extrinsic.call,
                context: context
            )

            let call = try callResult.getFirstCallOrThrow()

            let callAccountId = call.args.dest.accountId
            let callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)
            let isAccountMatched = accountId == callResult.extrinsicSender || accountId == callAccountId
            let currencyId = call.args.currencyId

            let amount = try? matchOrmlTransferAmount(
                from: eventRecords,
                metadata: metadata,
                context: context
            )

            return (callPath, isAccountMatched, callAccountId, callResult.extrinsicSender, currencyId, amount ?? 0)
        }
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
                fee: fee?.amount,
                feeAssetId: nil,
                peerId: executedValue.to,
                amount: nil,
                isSuccess: executedValue.isSuccess,
                assetId: assetId,
                swap: nil
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
            let maybeSender: AccountId? = try extrinsic.getSignedExtrinsic()?.signature.address.map(
                to: MultiAddress.self,
                with: runtimeJsonContext.toRawContext()
            ).accountId

            guard let extrinsicSender = maybeSender else {
                return nil
            }

            let call: RuntimeCall<NoRuntimeArgs>
            let isAccountMatched: Bool
            let callSender: AccountId

            if extrinsicSender == accountId {
                call = try extrinsic.call.map(to: RuntimeCall<NoRuntimeArgs>.self)
                isAccountMatched = true
                callSender = extrinsicSender
            } else {
                let callMapper = NestedExtrinsicCallMapper(extrinsicSender: extrinsicSender)
                let result = try callMapper.mapNotNestedCall(
                    call: extrinsic.call,
                    context: runtimeJsonContext
                )

                call = try result.getFirstCallOrThrow()

                isAccountMatched = accountId == result.callSender
                callSender = result.callSender
            }

            let callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)

            guard
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
                sender: extrinsicSender,
                eventRecords: eventRecords,
                metadata: metadata,
                runtimeJsonContext: runtimeJsonContext
            )

            guard let assetId = chain.utilityAssets().first?.assetId ?? chain.assets.first?.assetId else {
                return nil
            }

            return ExtrinsicProcessingResult(
                sender: callSender,
                callPath: callPath,
                call: extrinsic.call,
                extrinsicHash: nil,
                fee: fee?.amount,
                feeAssetId: nil,
                peerId: nil,
                amount: nil,
                isSuccess: isSuccess,
                assetId: assetId,
                swap: nil
            )

        } catch {
            return nil
        }
    }

    func matchAssetsTransfer(
        extrinsicIndex: UInt32,
        extrinsic: Extrinsic,
        eventRecords: [EventRecord],
        codingFactory: RuntimeCoderFactoryProtocol,
        context: RuntimeJsonContext
    ) -> ExtrinsicProcessingResult? {
        do {
            let metadata = codingFactory.metadata

            let rawContext = context.toRawContext()
            let maybeAddress = extrinsic.getSignedExtrinsic()?.signature.address
            let maybeSender = try maybeAddress?.map(to: MultiAddress.self, with: rawContext).accountId

            guard let sender = maybeSender else {
                return nil
            }

            let result = try parseAssetsExtrinsic(extrinsic, sender: sender, context: context)

            guard result.isAccountMatched else {
                return nil
            }

            let status = matchStatus(for: extrinsicIndex, eventRecords: eventRecords, metadata: metadata)

            guard let isSuccess = status else {
                return nil
            }

            let fee = findAssetsFee(
                for: extrinsicIndex,
                sender: sender,
                eventRecords: eventRecords,
                codingFactory: codingFactory
            )

            let peerId = accountId == result.callSenderAccountId ? result.callAccountId : result.callSenderAccountId

            let remotePalletName = result.callPath.moduleName
            let remoteAssetId = try StatemineAssetSerializer.encode(
                assetId: result.callAssetId,
                palletName: remotePalletName,
                codingFactory: codingFactory
            )

            let maybeAsset = chain.assets.first { asset in
                guard
                    asset.type == AssetType.statemine.rawValue,
                    let typeExtra = try? asset.typeExtras?.map(to: StatemineAssetExtras.self) else {
                    return false
                }

                let localPalletName = typeExtra.palletName ?? PalletAssets.name

                return remotePalletName == localPalletName && typeExtra.assetId == remoteAssetId
            }

            guard let asset = maybeAsset else {
                return nil
            }

            return ExtrinsicProcessingResult(
                sender: result.callSenderAccountId,
                callPath: result.callPath,
                call: extrinsic.call,
                extrinsicHash: nil,
                fee: fee?.amount,
                feeAssetId: fee?.assetId,
                peerId: peerId,
                amount: result.callAmount,
                isSuccess: isSuccess,
                assetId: asset.assetId,
                swap: nil
            )
        } catch {
            return nil
        }
    }

    private func parseAssetsExtrinsic(
        _ extrinsic: Extrinsic,
        sender: AccountId,
        context: RuntimeJsonContext
    ) throws -> AssetsParsingResult {
        let callMapper = NestedExtrinsicCallMapper(extrinsicSender: sender)

        let callResult: NestedExtrinsicCallMapResult<RuntimeCall<PalletAssets.TransferCall>>
        callResult = try callMapper.mapRuntimeCall(
            call: extrinsic.call,
            context: context
        )

        let call = try callResult.getFirstCallOrThrow()

        let callAccountId = call.args.target.accountId
        let callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)
        let isAccountMatched = accountId == callResult.callSender || accountId == callAccountId
        let assetId = call.args.assetId

        return (callPath, isAccountMatched, callAccountId, callResult.callSender, assetId, call.args.amount)
    }

    func matchBalancesTransfer(
        extrinsicIndex: UInt32,
        extrinsic: Extrinsic,
        eventRecords: [EventRecord],
        metadata: RuntimeMetadataProtocol,
        context: RuntimeJsonContext
    ) -> ExtrinsicProcessingResult? {
        do {
            let maybeSender: AccountId? = try extrinsic.getSignedExtrinsic()?.signature.address.map(
                to: MultiAddress.self,
                with: context.toRawContext()
            ).accountId

            guard let sender = maybeSender else {
                return nil
            }

            let extrinsicEventRecords = eventRecords.filter { $0.extrinsicIndex == extrinsicIndex }
            let result = try parseBalancesExtrinsic(
                extrinsic,
                eventRecords: extrinsicEventRecords,
                metadata: metadata,
                sender: sender,
                context: context
            )

            guard
                result.callPath.isBalancesTransfer,
                result.isAccountMatched,
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

            let peerId = accountId == result.callSenderId ? result.callAccountId : result.callSenderId

            guard let assetId = chain.utilityAssets().first?.assetId ?? chain.assets.first?.assetId else {
                return nil
            }

            return ExtrinsicProcessingResult(
                sender: result.callSenderId,
                callPath: result.callPath,
                call: extrinsic.call,
                extrinsicHash: nil,
                fee: fee?.amount,
                feeAssetId: nil,
                peerId: peerId,
                amount: result.callAmount,
                isSuccess: isSuccess,
                assetId: assetId,
                swap: nil
            )

        } catch {
            return nil
        }
    }

    private func parseBalancesExtrinsic(
        _ extrinsic: Extrinsic,
        eventRecords: [EventRecord],
        metadata: RuntimeMetadataProtocol,
        sender: AccountId,
        context: RuntimeJsonContext
    ) throws -> BalancesParsingResult {
        let callMapper = NestedExtrinsicCallMapper(extrinsicSender: sender)

        if
            let callResult: NestedExtrinsicCallMapResult<RuntimeCall<TransferCall>> = try? callMapper.mapRuntimeCall(
                call: extrinsic.call,
                context: context
            ) {
            let call = try callResult.getFirstCallOrThrow()

            let callAccountId = call.args.dest.accountId
            let callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)
            let isAccountMatched = accountId == callResult.callSender || accountId == callAccountId

            return (callPath, isAccountMatched, callAccountId, callResult.callSender, call.args.value)
        } else {
            let callResult: NestedExtrinsicCallMapResult<RuntimeCall<TransferAllCall>> = try callMapper.mapRuntimeCall(
                call: extrinsic.call,
                context: context
            )

            let call = try callResult.getFirstCallOrThrow()

            let callAccountId = call.args.dest.accountId
            let callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)
            let isAccountMatched = accountId == callResult.callSender || accountId == callAccountId

            let amount = try? matchBalancesTransferAmount(
                from: eventRecords,
                metadata: metadata,
                context: context
            )

            return (callPath, isAccountMatched, callAccountId, callResult.callSender, amount ?? 0)
        }
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

    func matchEquilibriumTransfer(
        extrinsicIndex: UInt32,
        extrinsic: Extrinsic,
        eventRecords: [EventRecord],
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> ExtrinsicProcessingResult? {
        do {
            let equilibriumTransfer = CallCodingPath.equilibriumTransfer
            guard extrinsic.call.moduleName?.stringValue == equilibriumTransfer.moduleName,
                  extrinsic.call.callName?.stringValue == equilibriumTransfer.callName else {
                return nil
            }
            let metadata = codingFactory.metadata
            let context = codingFactory.createRuntimeJsonContext()

            let optExtrinsicSender: AccountId? = try extrinsic.getSignedExtrinsic()?.signature.address.map(
                to: MultiAddress.self,
                with: context.toRawContext()
            ).accountId

            guard let extrinsicSender = optExtrinsicSender else {
                return nil
            }

            let eventRecords = eventRecords.filter { $0.extrinsicIndex == extrinsicIndex }

            let callMapper = NestedExtrinsicCallMapper(extrinsicSender: extrinsicSender)

            let optCallResult: NestedExtrinsicCallMapResult<RuntimeCall<EquilibriumTokenTransfer>>?
            optCallResult = try? callMapper.mapRuntimeCall(call: extrinsic.call, context: context)

            guard let callResult = optCallResult else {
                return nil
            }

            let call = try callResult.getFirstCallOrThrow()
            let callAccountId = call.args.destinationAccountId
            let callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)
            let isAccountMatched = accountId == callResult.callSender || accountId == callAccountId

            guard callPath.isEquilibriumTransfer, isAccountMatched else {
                return nil
            }

            guard let status = matchStatus(
                for: extrinsicIndex,
                eventRecords: eventRecords,
                metadata: metadata
            ) else {
                return nil
            }

            let fee = findFee(
                for: extrinsicIndex,
                sender: extrinsicSender,
                eventRecords: eventRecords,
                metadata: metadata,
                runtimeJsonContext: context
            )

            let peerId = accountId == callResult.callSender ? callAccountId : callResult.callSender
            guard let assetId = chain.equilibriumAssets.first(where: {
                $0.equilibriumAssetId == call.args.assetId
            })?.assetId else {
                return nil
            }

            return ExtrinsicProcessingResult(
                sender: callResult.callSender,
                callPath: callPath,
                call: extrinsic.call,
                extrinsicHash: nil,
                fee: fee?.amount,
                feeAssetId: nil,
                peerId: peerId,
                amount: call.args.value,
                isSuccess: status,
                assetId: assetId,
                swap: nil
            )

        } catch {
            return nil
        }
    }
}
