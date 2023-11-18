import Foundation
import BigInt
import SubstrateSdk

private struct SwapExtrinsicCallArgs {
    let receiver: AccountId
    let amountIn: BigUInt
    let amountOut: BigUInt
    let path: [AssetConversionPallet.AssetId]
}

private struct SwapExtrinsicParsingResult {
    let receiver: AccountId
    let assetIdIn: UInt32
    let amountIn: BigUInt
    let assetIdOut: UInt32
    let amountOut: BigUInt
    let callPath: CallCodingPath
    let call: JSON
    let customFee: AssetTxPaymentPallet.AssetTxFeePaid?
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
            guard let swapResult = try parseAssetHubSwapExtrinsic(
                extrinsic,
                extrinsicIndex: extrinsicIndex,
                eventRecords: eventRecords,
                codingFactory: codingFactory
            ) else {
                return nil
            }

            let fee: BigUInt
            let feeAssetId: AssetModel.Id?

            let context = codingFactory.createRuntimeJsonContext()

            let maybeSender: AccountId? = try extrinsic.signature?.address.map(
                to: MultiAddress.self,
                with: context.toRawContext()
            ).accountId

            guard let sender = maybeSender else {
                return nil
            }

            if
                let customFee = swapResult.customFee,
                let remoteAssetId = try? customFee.assetId.map(
                    to: AssetConversionPallet.AssetId.self,
                    with: context.toRawContext()
                ),
                let localAsset = AssetHubTokensConverter.convertFromMultilocationToLocal(
                    remoteAssetId,
                    chain: chain,
                    conversionClosure: AssetHubTokensConverter.createPoolAssetToLocalClosure(
                        for: chain,
                        codingFactory: codingFactory
                    )
                ) {
                fee = customFee.actualFee
                feeAssetId = localAsset.asset.assetId
            } else {
                let optNativeFee = findFee(
                    for: extrinsicIndex,
                    sender: sender,
                    eventRecords: eventRecords,
                    metadata: codingFactory.metadata,
                    runtimeJsonContext: context
                )

                guard let nativeFee = optNativeFee else {
                    return nil
                }

                fee = nativeFee
                feeAssetId = chain.utilityAsset()?.assetId
            }

            return .init(
                sender: sender,
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
        extrinsicIndex: UInt32,
        eventRecords: [EventRecord],
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> SwapExtrinsicParsingResult? {
        let context = codingFactory.createRuntimeJsonContext()

        guard
            let call = try? extrinsic.call.map(to: RuntimeCall<JSON>.self, with: context.toRawContext()),
            AssetConversionPallet.isSwap(.init(moduleName: call.moduleName, callName: call.callName)) else {
            return nil
        }

        let customFee = try findFeeInCustomAsset(
            in: eventRecords,
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
                eventRecords: eventRecords,
                customFee: customFee,
                codingFactory: codingFactory
            )
        } else {
            return try findFailedAssetHubSwapResult(
                from: call,
                customFee: customFee,
                codingFactory: codingFactory
            )
        }
    }

    private func findSuccessAssetHubSwapResult(
        from call: RuntimeCall<JSON>,
        eventRecords: [EventRecord],
        customFee: AssetTxPaymentPallet.AssetTxFeePaid?,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> SwapExtrinsicParsingResult? {
        let callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)

        let context = codingFactory.createRuntimeJsonContext()
        let metadata = codingFactory.metadata

        let swapEvents: [AssetConversionPallet.SwapExecutedEvent] = eventRecords.compactMap { record in
            guard
                let eventPath = metadata.createEventCodingPath(from: record.event),
                AssetConversionPallet.swapExecutedEvent == eventPath else {
                return nil
            }

            return try? record.event.params.map(
                to: AssetConversionPallet.SwapExecutedEvent.self,
                with: context.toRawContext()
            )
        }

        guard
            let swap = try findSwap(swapEvents, customFee: customFee),
            let remoteAssetIn = swap.path.first,
            let remoteAssetOut = swap.path.last
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
        customFee: AssetTxPaymentPallet.AssetTxFeePaid?,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> SwapExtrinsicParsingResult? {
        let callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)

        let conversionClosure = AssetHubTokensConverter.createPoolAssetToLocalClosure(
            for: chain,
            codingFactory: codingFactory
        )

        let context = codingFactory.createRuntimeJsonContext()
        let args: SwapExtrinsicCallArgs

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

    private func findSwap(
        _ swapEvents: [AssetConversionPallet.SwapExecutedEvent],
        customFee: AssetTxPaymentPallet.AssetTxFeePaid?
    ) -> AssetConversionPallet.SwapExecutedEvent? {
        guard customFee != nil else {
            return swapEvents.first
        }

        let optFeeSwap = swapEvents.first
        let swapsAfterFee = swapEvents.dropFirst()

        guard
            let feeSwap = optFeeSwap,
            let targetSwap = swapsAfterFee.first,
            let feeAssetOut = feeSwap.path.last,
            case .native = AssetHubTokensConverter.convertFromMultilocation(feeAssetOut, chain: chain) else {
            return nil
        }

        return targetSwap
    }
}
