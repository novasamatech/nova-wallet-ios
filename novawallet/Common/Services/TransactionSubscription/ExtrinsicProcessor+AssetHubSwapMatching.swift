import Foundation
import BigInt
import SubstrateSdk

private struct AssetHubSwapExtrinsicCallArgs {
    let receiver: AccountId
    let amountIn: BigUInt
    let amountOut: BigUInt
    let path: [AssetConversionPallet.AssetId]
}

private struct AssetHubSwapExtrinsicParsingResult {
    let callSender: AccountId
    let receiver: AccountId
    let assetIdIn: UInt32
    let amountIn: BigUInt
    let assetIdOut: UInt32
    let amountOut: BigUInt
    let callPath: CallCodingPath
    let call: JSON
    let customFee: ExtrinsicProcessor.Fee?
    let isSuccess: Bool
}

extension ExtrinsicProcessor {
    func matchAssetHubSwap(
        extrinsicIndex: UInt32,
        extrinsic: Extrinsic,
        eventRecords: [EventRecord],
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> ExtrinsicProcessingResult? {
        do {
            let context = codingFactory.createRuntimeJsonContext()

            let maybeExtrinsicSender: AccountId? = try extrinsic.getSignedExtrinsic()?.signature.address.map(
                to: MultiAddress.self,
                with: context.toRawContext()
            ).accountId

            guard let extrinsicSender = maybeExtrinsicSender else {
                return nil
            }

            guard let swapResult = try parseAssetHubSwapExtrinsic(
                extrinsic,
                sender: extrinsicSender,
                extrinsicIndex: extrinsicIndex,
                eventRecords: eventRecords,
                codingFactory: codingFactory
            ) else {
                return nil
            }

            let fee: BigUInt
            let feeAssetId: AssetModel.Id?

            if
                let customFeeAmount = swapResult.customFee?.amount,
                let customFeeAssetId = swapResult.customFee?.assetId {
                fee = customFeeAmount
                feeAssetId = customFeeAssetId
            } else {
                let optNativeFee = findFee(
                    for: extrinsicIndex,
                    sender: extrinsicSender,
                    eventRecords: eventRecords,
                    metadata: codingFactory.metadata,
                    runtimeJsonContext: context
                )

                guard let nativeFee = optNativeFee else {
                    return nil
                }

                fee = nativeFee.amount
                feeAssetId = chain.utilityAsset()?.assetId
            }

            return .init(
                sender: swapResult.callSender,
                callPath: swapResult.callPath,
                call: swapResult.call,
                extrinsicHash: nil,
                fee: fee,
                feeAssetId: feeAssetId,
                peerId: swapResult.receiver,
                amount: nil,
                isSuccess: swapResult.isSuccess,
                assetId: swapResult.assetIdIn,
                swap: .init(
                    assetIdIn: swapResult.assetIdIn,
                    assetIdOut: swapResult.assetIdOut,
                    amountIn: swapResult.amountIn,
                    amountOut: swapResult.amountOut
                )
            )

        } catch {
            return nil
        }
    }

    private func parseAssetHubSwapExtrinsic(
        _ extrinsic: Extrinsic,
        sender: AccountId,
        extrinsicIndex: UInt32,
        eventRecords: [EventRecord],
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> AssetHubSwapExtrinsicParsingResult? {
        let context = codingFactory.createRuntimeJsonContext()

        let callMapper = NestedExtrinsicCallMapper(extrinsicSender: sender)

        let optResult = try? callMapper.map(
            call: extrinsic.call,
            context: context
        ) { callJson in
            do {
                let call = try callJson.map(to: RuntimeCall<JSON>.self, with: context.toRawContext())
                return AssetConversionPallet.isSwap(.init(moduleName: call.moduleName, callName: call.callName))
            } catch {
                return false
            }
        }

        guard let mappingResult = optResult,
              let call = try? mappingResult.getFirstCallOrThrow().map(
                  to: RuntimeCall<JSON>.self,
                  with: context.toRawContext()
              ) else {
            return nil
        }

        guard mappingResult.callSender == accountId else {
            return nil
        }

        let customFee = findAssetsCustomFee(
            for: extrinsicIndex,
            eventRecords: eventRecords,
            codingFactory: codingFactory
        )

        guard
            let isSuccess = matchStatus(
                for: extrinsicIndex,
                eventRecords: eventRecords,
                metadata: codingFactory.metadata
            ) else {
            return nil
        }

        if isSuccess {
            return try findSuccessAssetHubSwapResult(
                from: call,
                callSender: mappingResult.callSender,
                eventRecords: eventRecords.filter { $0.extrinsicIndex == extrinsicIndex },
                customFee: customFee,
                codingFactory: codingFactory
            )
        } else {
            return try findFailedAssetHubSwapResult(
                from: call,
                callSender: mappingResult.callSender,
                customFee: customFee,
                codingFactory: codingFactory
            )
        }
    }

    private func findSuccessAssetHubSwapResult(
        from call: RuntimeCall<JSON>,
        callSender: AccountId,
        eventRecords: [EventRecord],
        customFee: Fee?,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> AssetHubSwapExtrinsicParsingResult? {
        let callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)

        let context = codingFactory.createRuntimeJsonContext()
        let metadata = codingFactory.metadata

        let swapEvents: [AssetConversionPallet.SwapExecutedEvent] = eventRecords.compactMap { record in
            guard
                let eventPath = metadata.createEventCodingPath(from: record.event),
                AssetConversionPallet.swapExecutedEvent == eventPath else {
                return nil
            }

            let type = AssetConversionPallet.SwapExecutedEvent.self
            return try? record.event.params.map(to: type, with: context.toRawContext())
        }

        guard
            let swap = swapEvents.last,
            let remoteAssetIn = swap.path.first?.asset,
            let remoteAssetOut = swap.path.last?.asset
        else {
            return nil
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
            return nil
        }

        return .init(
            callSender: callSender,
            receiver: swap.sendTo,
            assetIdIn: assetIn.chainAssetId.assetId,
            amountIn: swap.amountIn,
            assetIdOut: assetOut.chainAssetId.assetId,
            amountOut: swap.amountOut,
            callPath: callPath,
            call: call.args,
            customFee: customFee,
            isSuccess: true
        )
    }

    private func findFailedAssetHubSwapResult(
        from call: RuntimeCall<JSON>,
        callSender: AccountId,
        customFee: Fee?,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> AssetHubSwapExtrinsicParsingResult? {
        let callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)

        let conversionClosure = AssetHubTokensConverter.createPoolAssetToLocalClosure(
            for: chain,
            codingFactory: codingFactory
        )

        let context = codingFactory.createRuntimeJsonContext()
        let args: AssetHubSwapExtrinsicCallArgs

        switch callPath {
        case AssetConversionPallet.swapExactTokenForTokensPath:
            let type = AssetConversionPallet.SwapExactTokensForTokensCall.self
            let call = try call.args.map(to: type, with: context.toRawContext())

            args = .init(receiver: call.sendTo, amountIn: call.amountIn, amountOut: call.amountOutMin, path: call.path)

        case AssetConversionPallet.swapTokenForExactTokens:
            let type = AssetConversionPallet.SwapTokensForExactTokensCall.self
            let call = try call.args.map(to: type, with: context.toRawContext())

            args = .init(receiver: call.sendTo, amountIn: call.amountInMax, amountOut: call.amountOut, path: call.path)
        default:
            return nil
        }

        guard
            let remoteAssetIn = args.path.first,
            let remoteAssetOut = args.path.last,
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
            return nil
        }

        return .init(
            callSender: callSender,
            receiver: args.receiver,
            assetIdIn: assetIn.asset.assetId,
            amountIn: args.amountIn,
            assetIdOut: assetOut.asset.assetId,
            amountOut: args.amountOut,
            callPath: callPath,
            call: call.args,
            customFee: customFee,
            isSuccess: false
        )
    }
}
