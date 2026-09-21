import Foundation
import BigInt
import SubstrateSdk

enum AssetHubSwapMatch {
    case notMatched
    case unresolved
    case matched(ExtrinsicProcessingResult)
}

private enum AssetHubSwapMatchingError: Error {
    case unresolvedCommission
}

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
    ) -> AssetHubSwapMatch {
        do {
            let context = codingFactory.createRuntimeJsonContext()

            guard let extrinsicSender = ExtrinsicExtraction.getSender(
                from: extrinsic,
                codingFactory: codingFactory
            ) else {
                return .notMatched
            }

            guard let swapResult = try parseAssetHubSwapExtrinsic(
                extrinsic,
                sender: extrinsicSender,
                extrinsicIndex: extrinsicIndex,
                eventRecords: eventRecords,
                codingFactory: codingFactory
            ) else {
                return .notMatched
            }

            let fee: BigUInt?
            let feeAssetId: AssetModel.Id?

            if
                let customFeeAmount = swapResult.customFee?.amount,
                let customFeeAssetId = swapResult.customFee?.assetId {
                fee = customFeeAmount
                feeAssetId = customFeeAssetId
            } else if let nativeFee = findFee(
                for: extrinsicIndex,
                sender: extrinsicSender,
                eventRecords: eventRecords,
                metadata: codingFactory.metadata,
                runtimeJsonContext: context
            ) {
                fee = nativeFee.amount
                feeAssetId = chain.utilityAsset()?.assetId
            } else {
                logger.debug("No fee found for Asset Hub swap \(extrinsicIndex) in \(chain.chainId)")

                fee = nil
                feeAssetId = nil
            }

            return .matched(.init(
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
            ))

        } catch AssetHubSwapMatchingError.unresolvedCommission {
            return .unresolved
        } catch {
            logger.debug("Asset Hub swap matching skipped for \(extrinsicIndex) in \(chain.chainId): \(error)")

            return .notMatched
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

        guard
            let isSuccess = matchStatus(
                for: extrinsicIndex,
                eventRecords: eventRecords,
                metadata: codingFactory.metadata
            ) else {
            return nil
        }

        let customFee = findAssetsCustomFee(
            for: extrinsicIndex,
            eventRecords: eventRecords,
            codingFactory: codingFactory
        )

        let extrinsicEvents = eventRecords.filter { $0.extrinsicIndex == extrinsicIndex }

        switch AssetHubCommissionHistoryParser(logger: logger).parse(
            extrinsic: extrinsic,
            sender: sender,
            account: accountId,
            events: extrinsicEvents.map(\.event),
            extrinsicSucceeded: isSuccess,
            chain: chain,
            codingFactory: codingFactory,
            beneficiaries: assetHubCommissionBeneficiaries
        ) {
        case .notCommissioned:
            break
        case let .recognizedButUnresolved(error):
            logger.error("Unresolved Asset Hub commission in \(chain.chainId): \(error)")

            throw AssetHubSwapMatchingError.unresolvedCommission
        case let .swap(swap):
            return .init(
                callSender: swap.sender,
                receiver: swap.receiver,
                assetIdIn: swap.assetIn,
                amountIn: swap.amountIn,
                assetIdOut: swap.assetOut,
                amountOut: swap.netAmountOut,
                callPath: swap.call.path,
                call: swap.call.args,
                customFee: customFee,
                isSuccess: swap.isSuccess
            )
        }

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

        if isSuccess {
            return try findSuccessAssetHubSwapResult(
                from: call,
                callSender: mappingResult.callSender,
                eventRecords: extrinsicEvents,
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

        guard let intendedArgs = try? extractAssetHubSwapCallArgs(from: call, codingFactory: codingFactory) else {
            return nil
        }

        let matchingEvents = swapEvents.filter {
            matches(swapEvent: $0, sender: callSender, callPath: callPath, args: intendedArgs)
        }

        guard
            matchingEvents.count == 1,
            let swap = matchingEvents.first,
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

        guard let args = try? extractAssetHubSwapCallArgs(from: call, codingFactory: codingFactory) else {
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

private extension ExtrinsicProcessor {
    func extractAssetHubSwapCallArgs(
        from call: RuntimeCall<JSON>,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> AssetHubSwapExtrinsicCallArgs? {
        let context = codingFactory.createRuntimeJsonContext()

        switch CallCodingPath(moduleName: call.moduleName, callName: call.callName) {
        case AssetConversionPallet.swapExactTokenForTokensPath:
            let type = AssetConversionPallet.SwapExactTokensForTokensCall.self
            let swapCall = try call.args.map(to: type, with: context.toRawContext())

            return .init(
                receiver: swapCall.sendTo,
                amountIn: swapCall.amountIn,
                amountOut: swapCall.amountOutMin,
                path: swapCall.path
            )
        case AssetConversionPallet.swapTokenForExactTokens:
            let type = AssetConversionPallet.SwapTokensForExactTokensCall.self
            let swapCall = try call.args.map(to: type, with: context.toRawContext())

            return .init(
                receiver: swapCall.sendTo,
                amountIn: swapCall.amountInMax,
                amountOut: swapCall.amountOut,
                path: swapCall.path
            )
        default:
            return nil
        }
    }

    func matches(
        swapEvent: AssetConversionPallet.SwapExecutedEvent,
        sender: AccountId,
        callPath: CallCodingPath,
        args: AssetHubSwapExtrinsicCallArgs
    ) -> Bool {
        let bounds: AssetConversionSwapBounds = callPath == AssetConversionPallet.swapExactTokenForTokensPath
            ? .exactIn(amountIn: args.amountIn, amountOutMin: args.amountOut)
            : .exactOut(amountOut: args.amountOut, amountInMax: args.amountIn)

        return AssetConversionSwapBounds.matches(
            event: swapEvent,
            origin: sender,
            receiver: args.receiver,
            path: args.path,
            bounds: bounds
        )
    }
}
