import Foundation
import BigInt
import SubstrateSdk

private struct HydraSwapExtrinsicCallArgs {
    let assetIn: HydraDx.AssetId
    let assetOut: HydraDx.AssetId
    let amountIn: BigUInt
    let amountOut: BigUInt
}

private struct HydraFee {
    let assetId: AssetModel.Id
    let amount: BigUInt
}

private struct HydraSwapExtrinsicParsingParams {
    let sender: AccountId
    let events: Set<EventCodingPath>
    let eventParser: (Event, EventCodingPath) throws -> HydraSwapExtrinsicCallArgs
    let calls: Set<CallCodingPath>
    let callParser: (RuntimeCall<JSON>) throws -> HydraSwapExtrinsicCallArgs
}

private struct HydraSwapExtrinsicParsingResult {
    let callSender: AccountId
    let assetIdIn: AssetModel.Id
    let amountIn: BigUInt
    let assetIdOut: AssetModel.Id
    let amountOut: BigUInt
    let callPath: CallCodingPath
    let call: JSON
    let isSuccess: Bool
}

extension ExtrinsicProcessor {
    func matchHydraSwap(
        extrinsicIndex: UInt32,
        extrinsic: Extrinsic,
        eventRecords: [EventRecord],
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> ExtrinsicProcessingResult? {
        do {
            let extrinsicEvents = eventRecords.filter { $0.extrinsicIndex == extrinsicIndex }

            guard let sender = ExtrinsicExtraction.getSender(from: extrinsic, codingFactory: codingFactory) else {
                return nil
            }

            let params = prepareParsingParams(for: sender, codingFactory: codingFactory)

            guard let swapResult = try parseHydraSwapExtrinsic(
                extrinsic,
                params: params,
                extrinsicIndex: extrinsicIndex,
                eventRecords: extrinsicEvents,
                codingFactory: codingFactory
            ) else {
                return nil
            }

            guard let fee = try findHydraFee(
                for: params,
                extrinsicIndex: extrinsicIndex,
                eventRecords: extrinsicEvents,
                codingFactory: codingFactory
            ) else {
                return nil
            }

            return .init(
                sender: swapResult.callSender,
                callPath: swapResult.callPath,
                call: swapResult.call,
                extrinsicHash: nil,
                fee: fee.amount,
                feeAssetId: fee.assetId,
                peerId: swapResult.callSender,
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

    // swiftlint:disable:next function_body_length
    private func prepareParsingParams(
        for sender: AccountId,
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> HydraSwapExtrinsicParsingParams {
        let context = codingFactory.createRuntimeJsonContext()

        return HydraSwapExtrinsicParsingParams(
            sender: sender,
            events: [
                HydraRouter.routeExecutedPath,
                HydraOmnipool.sellExecutedPath,
                HydraOmnipool.buyExecutedPath
            ],
            eventParser: { event, eventPath in
                switch eventPath {
                case HydraRouter.routeExecutedPath:
                    let model: HydraRouter.RouteExecutedEvent = try ExtrinsicExtraction.getEventParams(
                        from: event,
                        context: context
                    )

                    return HydraSwapExtrinsicCallArgs(
                        assetIn: model.assetIn,
                        assetOut: model.assetOut,
                        amountIn: model.amountIn,
                        amountOut: model.amountOut
                    )
                default:
                    // omnipool events has similar model

                    let model: HydraOmnipool.SwapExecuted = try ExtrinsicExtraction.getEventParams(
                        from: event,
                        context: context
                    )

                    return HydraSwapExtrinsicCallArgs(
                        assetIn: model.assetIn,
                        assetOut: model.assetOut,
                        amountIn: model.amountIn,
                        amountOut: model.amountOut
                    )
                }

            },
            calls: [
                HydraRouter.SellCall.callPath,
                HydraRouter.BuyCall.callPath,
                HydraOmnipool.SellCall.callPath,
                HydraOmnipool.BuyCall.callPath
            ],
            callParser: { call in
                switch CallCodingPath(moduleName: call.moduleName, callName: call.callName) {
                case HydraRouter.SellCall.callPath:
                    let model: HydraRouter.SellCall = try ExtrinsicExtraction.getCallArgs(
                        from: call.args,
                        context: context
                    )

                    return HydraSwapExtrinsicCallArgs(
                        assetIn: model.assetIn,
                        assetOut: model.assetOut,
                        amountIn: model.amountIn,
                        amountOut: model.minAmountOut
                    )
                case HydraRouter.BuyCall.callPath:
                    let model: HydraRouter.BuyCall = try ExtrinsicExtraction.getCallArgs(
                        from: call.args,
                        context: context
                    )

                    return HydraSwapExtrinsicCallArgs(
                        assetIn: model.assetIn,
                        assetOut: model.assetOut,
                        amountIn: model.maxAmountIn,
                        amountOut: model.amountOut
                    )
                case HydraOmnipool.SellCall.callPath:
                    let model: HydraOmnipool.SellCall = try ExtrinsicExtraction.getCallArgs(
                        from: call.args,
                        context: context
                    )

                    return HydraSwapExtrinsicCallArgs(
                        assetIn: model.assetIn,
                        assetOut: model.assetOut,
                        amountIn: model.amount,
                        amountOut: model.minBuyAmount
                    )
                case HydraOmnipool.BuyCall.callPath:
                    let model: HydraOmnipool.BuyCall = try ExtrinsicExtraction.getCallArgs(
                        from: call.args,
                        context: context
                    )

                    return HydraSwapExtrinsicCallArgs(
                        assetIn: model.assetIn,
                        assetOut: model.assetOut,
                        amountIn: model.maxSellAmount,
                        amountOut: model.amount
                    )
                default:
                    throw CommonError.dataCorruption
                }
            }
        )
    }

    private func parseHydraSwapExtrinsic(
        _ extrinsic: Extrinsic,
        params: HydraSwapExtrinsicParsingParams,
        extrinsicIndex: UInt32,
        eventRecords: [EventRecord],
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> HydraSwapExtrinsicParsingResult? {
        let context = codingFactory.createRuntimeJsonContext()

        let callMapper = NestedExtrinsicCallMapper(extrinsicSender: params.sender)

        let optResult = try? callMapper.map(
            call: extrinsic.call,
            context: context
        ) { callJson in
            do {
                let call = try ExtrinsicExtraction.getCall(from: callJson, context: context)
                return params.calls.contains(.init(moduleName: call.moduleName, callName: call.callName))
            } catch {
                return false
            }
        }

        guard let mappingResult = optResult,
              let jsonCall = try? mappingResult.getFirstCallOrThrow(),
              let call = try? ExtrinsicExtraction.getCall(from: jsonCall, context: context) else {
            return nil
        }

        guard mappingResult.callSender == accountId else {
            return nil
        }

        guard
            let isSuccess = matchStatus(
                for: extrinsicIndex,
                eventRecords: eventRecords,
                metadata: codingFactory.metadata
            ) else {
            return nil
        }

        if isSuccess {
            return try findSuccessHydraSwapResult(
                from: params,
                callSender: mappingResult.callSender,
                call: call,
                eventRecords: eventRecords,
                codingFactory: codingFactory
            )
        } else {
            return try findFailedHydraSwapResult(
                from: params,
                callSender: mappingResult.callSender,
                call: call,
                codingFactory: codingFactory
            )
        }
    }

    private func findSuccessHydraSwapResult(
        from params: HydraSwapExtrinsicParsingParams,
        callSender: AccountId,
        call: RuntimeCall<JSON>,
        eventRecords: [EventRecord],
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> HydraSwapExtrinsicParsingResult? {
        let callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)

        let metadata = codingFactory.metadata

        let optSwapEvent = eventRecords.last { metadata.eventMatches($0.event, oneOf: params.events) }

        guard
            let eventRecord = optSwapEvent,
            let eventCodingPath = metadata.createEventCodingPath(from: eventRecord.event),
            let swapArgs = try? params.eventParser(eventRecord.event, eventCodingPath) else {
            return nil
        }

        let assetIn = try HydraDxTokenConverter.converToLocal(
            for: swapArgs.assetIn,
            chain: chain,
            codingFactory: codingFactory
        )

        let assetOut = try HydraDxTokenConverter.converToLocal(
            for: swapArgs.assetOut,
            chain: chain,
            codingFactory: codingFactory
        )

        return HydraSwapExtrinsicParsingResult(
            callSender: callSender,
            assetIdIn: assetIn.assetId,
            amountIn: swapArgs.amountIn,
            assetIdOut: assetOut.assetId,
            amountOut: swapArgs.amountOut,
            callPath: callPath,
            call: call.args,
            isSuccess: true
        )
    }

    private func findFailedHydraSwapResult(
        from params: HydraSwapExtrinsicParsingParams,
        callSender: AccountId,
        call: RuntimeCall<JSON>,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> HydraSwapExtrinsicParsingResult? {
        let callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)

        guard let swapArgs = try? params.callParser(call) else {
            return nil
        }

        let assetIn = try HydraDxTokenConverter.converToLocal(
            for: swapArgs.assetIn,
            chain: chain,
            codingFactory: codingFactory
        )

        let assetOut = try HydraDxTokenConverter.converToLocal(
            for: swapArgs.assetOut,
            chain: chain,
            codingFactory: codingFactory
        )

        return HydraSwapExtrinsicParsingResult(
            callSender: callSender,
            assetIdIn: assetIn.assetId,
            amountIn: swapArgs.amountIn,
            assetIdOut: assetOut.assetId,
            amountOut: swapArgs.amountOut,
            callPath: callPath,
            call: call.args,
            isSuccess: false
        )
    }

    private func findHydraFee(
        for params: HydraSwapExtrinsicParsingParams,
        extrinsicIndex: UInt32,
        eventRecords: [EventRecord],
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> HydraFee? {
        if
            let customFee = try findHydraCustomFee(
                in: eventRecords,
                swapEvents: params.events,
                codingFactory: codingFactory
            ) {
            return customFee
        } else {
            let optNativeFee = findFee(
                for: extrinsicIndex,
                sender: params.sender,
                eventRecords: eventRecords,
                metadata: codingFactory.metadata,
                runtimeJsonContext: codingFactory.createRuntimeJsonContext()
            )

            guard
                let feeAssetId = chain.utilityChainAssetId()?.assetId,
                let nativeFee = optNativeFee else {
                return nil
            }

            return HydraFee(assetId: feeAssetId, amount: nativeFee)
        }
    }

    private func findHydraCustomFee(
        in events: [EventRecord],
        swapEvents: Set<EventCodingPath>,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> HydraFee? {
        let metadata = codingFactory.metadata

        let swapIndex = events.lastIndex { metadata.eventMatches($0.event, oneOf: swapEvents) } ?? 0

        let feePaidPath = TransactionPaymentPallet.feePaidPath
        let optFeePaidIndex = events.lastIndex { metadata.eventMatches($0.event, path: feePaidPath) }

        guard let feePaidIndex = optFeePaidIndex,
              swapIndex < feePaidIndex else {
            return nil
        }

        let depositedPath = TokensPallet.depositedEventPath
        let optDepositEvent = events[swapIndex ..< feePaidIndex].first {
            metadata.eventMatches($0.event, path: depositedPath)
        }

        let context = codingFactory.createRuntimeJsonContext()

        guard
            let depositedEvent = optDepositEvent,
            let depositedModel: TokensPallet.DepositedEvent<StringScaleMapper<BigUInt>> =
            try? ExtrinsicExtraction.getEventParams(
                from: depositedEvent.event,
                context: context
            ) else {
            return nil
        }

        let assetId = try HydraDxTokenConverter.converToLocal(
            for: depositedModel.currencyId.value,
            chain: chain,
            codingFactory: codingFactory
        ).assetId

        return HydraFee(assetId: assetId, amount: depositedModel.amount)
    }
}
