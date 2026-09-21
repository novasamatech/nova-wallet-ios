import Foundation
import SubstrateSdk

enum AssetHubExchangeEventError: Error {
    case unexpectedOrigin
    case missingOrAmbiguousSwap
    case missingOrAmbiguousCommission
    case unexpectedCommissionAmount
    case outputUnderflow
}

final class AssetConversionEventParser {
    let logger: LoggerProtocol

    init(logger: LoggerProtocol) {
        self.logger = logger
    }

    func extractDeposit(
        from events: [Event],
        params: AssetHubExchangeSwapParams,
        origin: AccountId,
        using codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> Balance {
        guard origin == params.callArgs.receiver else {
            throw AssetHubExchangeEventError.unexpectedOrigin
        }

        let swaps = try findSwaps(in: events, params: params, origin: origin, using: codingFactory)

        guard swaps.count == 1, let measured = swaps.first else {
            throw AssetHubExchangeEventError.missingOrAmbiguousSwap
        }

        guard let commission = params.commission else {
            return measured.event.amountOut
        }

        let collections = try findCollections(
            in: Array(events.suffix(from: measured.index + 1)),
            commission: commission,
            origin: origin,
            using: codingFactory
        )

        guard collections.count == 1, let collected = collections.first else {
            throw AssetHubExchangeEventError.missingOrAmbiguousCommission
        }

        guard collected == commission.amount else {
            throw AssetHubExchangeEventError.unexpectedCommissionAmount
        }

        guard measured.event.amountOut >= collected else {
            throw AssetHubExchangeEventError.outputUnderflow
        }

        logger.debug("Measured swap output \(measured.event.amountOut), collected \(collected)")

        return measured.event.amountOut - collected
    }
}

private extension AssetConversionEventParser {
    struct MeasuredSwap {
        let index: Int
        let event: AssetConversionPallet.SwapExecutedEvent
    }

    func findSwaps(
        in events: [Event],
        params: AssetHubExchangeSwapParams,
        origin: AccountId,
        using codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> [MeasuredSwap] {
        let context = codingFactory.createRuntimeJsonContext()

        return try events.enumerated().compactMap { index, event in
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
                swap.path.map(\.asset) == params.path,
                matches(swap: swap, with: params.swap) else {
                return nil
            }

            return MeasuredSwap(index: index, event: swap)
        }
    }

    func matches(
        swap: AssetConversionPallet.SwapExecutedEvent,
        with call: AssetHubExchangeSwapParams.Swap
    ) -> Bool {
        switch call {
        case let .exactIn(exactIn):
            return swap.amountIn == exactIn.amountIn && swap.amountOut >= exactIn.amountOutMin
        case let .exactOut(exactOut):
            return swap.amountOut == exactOut.amountOut && swap.amountIn <= exactOut.amountInMax
        }
    }

    func findCollections(
        in events: [Event],
        commission: AssetHubExchangeSwapParams.Commission,
        origin: AccountId,
        using codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> [Balance] {
        let context = codingFactory.createRuntimeJsonContext()

        switch commission.assetStorageInfo {
        case .native:
            return try events.compactMap { event in
                guard codingFactory.metadata.eventMatches(event, path: BalancesPallet.balancesTransfer) else {
                    return nil
                }

                let transfer: BalancesPallet.TransferEvent = try ExtrinsicExtraction.getEventParams(
                    from: event,
                    context: context
                )

                guard transfer.sender == origin, transfer.receiver == commission.beneficiary else {
                    return nil
                }

                return transfer.amount
            }
        case let .statemine(info):
            return try events.compactMap { event in
                guard
                    codingFactory.metadata.eventMatches(
                        event,
                        path: PalletAssets.transferredPath(for: info.palletName)
                    ) else {
                    return nil
                }

                let transfer: PalletAssets.TransferredEvent = try ExtrinsicExtraction.getEventParams(
                    from: event,
                    context: context
                )

                guard
                    transfer.assetId == info.assetId,
                    transfer.sender == origin,
                    transfer.receiver == commission.beneficiary else {
                    return nil
                }

                return transfer.amount
            }
        case .orml, .ormlHydrationEvm, .erc20, .evmNative, .equilibrium:
            throw AssetHubExchangePreparationError.unsupportedStorage
        }
    }
}
