import Foundation
import SubstrateSdk

enum AssetHubExchangeEventError: Error, Equatable {
    case unexpectedOrigin
    case swapNotDispatched
    case missingOrAmbiguousSwap
    case missingOrAmbiguousCommission
    case unexpectedCommissionAmount
    case outputUnderflow
}

enum AssetConversionSwapBounds {
    case exactIn(amountIn: Balance, amountOutMin: Balance)
    case exactOut(amountOut: Balance, amountInMax: Balance)

    init(swap: AssetHubExchangeSwapParams.Swap) {
        switch swap {
        case let .exactIn(call):
            self = .exactIn(amountIn: call.amountIn, amountOutMin: call.amountOutMin)
        case let .exactOut(call):
            self = .exactOut(amountOut: call.amountOut, amountInMax: call.amountInMax)
        }
    }

    func matches(event: AssetConversionPallet.SwapExecutedEvent) -> Bool {
        switch self {
        case let .exactIn(amountIn, amountOutMin):
            return event.amountIn == amountIn && event.amountOut >= amountOutMin
        case let .exactOut(amountOut, amountInMax):
            return event.amountOut == amountOut && event.amountIn <= amountInMax
        }
    }

    static func matches(
        event: AssetConversionPallet.SwapExecutedEvent,
        origin: AccountId,
        receiver: AccountId,
        path: [AssetConversionPallet.AssetId],
        bounds: AssetConversionSwapBounds
    ) -> Bool {
        event.who == origin &&
            event.sendTo == receiver &&
            event.path.map(\.asset) == path &&
            bounds.matches(event: event)
    }
}

struct AssetConversionSwapVerification {
    struct Commission {
        let amount: Balance
        let beneficiary: AccountId
        let assetStorageInfo: AssetStorageInfo
    }

    let receiver: AccountId
    let path: [AssetConversionPallet.AssetId]
    let bounds: AssetConversionSwapBounds
    let commission: Commission?
}

final class AssetConversionEventParser {
    struct Measurement {
        let amountIn: Balance
        let netAmountOut: Balance
    }

    let logger: LoggerProtocol

    init(logger: LoggerProtocol) {
        self.logger = logger
    }

    func extractDeposit(
        from events: [Event],
        verification: AssetConversionSwapVerification,
        origin: AccountId,
        using codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> Balance {
        try measure(
            from: events,
            verification: verification,
            origin: origin,
            using: codingFactory
        ).netAmountOut
    }

    func measure(
        from events: [Event],
        verification: AssetConversionSwapVerification,
        origin: AccountId,
        using codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> Measurement {
        guard origin == verification.receiver else {
            throw AssetHubExchangeEventError.unexpectedOrigin
        }

        guard events.contains(where: { isSwapExecuted($0, using: codingFactory) }) else {
            throw AssetHubExchangeEventError.swapNotDispatched
        }

        let swaps = try findSwaps(
            in: events,
            verification: verification,
            origin: origin,
            using: codingFactory
        )

        guard swaps.count == 1, let measured = swaps.first else {
            throw AssetHubExchangeEventError.missingOrAmbiguousSwap
        }

        guard let commission = verification.commission else {
            return Measurement(
                amountIn: measured.event.amountIn,
                netAmountOut: measured.event.amountOut
            )
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

        return Measurement(
            amountIn: measured.event.amountIn,
            netAmountOut: measured.event.amountOut - collected
        )
    }
}

private extension AssetConversionEventParser {
    struct MeasuredSwap {
        let index: Int
        let event: AssetConversionPallet.SwapExecutedEvent
    }

    func isSwapExecuted(_ event: Event, using codingFactory: RuntimeCoderFactoryProtocol) -> Bool {
        codingFactory.metadata.eventMatches(event, path: AssetConversionPallet.swapExecutedEvent)
    }

    func findSwaps(
        in events: [Event],
        verification: AssetConversionSwapVerification,
        origin: AccountId,
        using codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> [MeasuredSwap] {
        let context = codingFactory.createRuntimeJsonContext()

        return try events.enumerated().compactMap { index, event in
            guard isSwapExecuted(event, using: codingFactory) else {
                return nil
            }

            let swap: AssetConversionPallet.SwapExecutedEvent = try ExtrinsicExtraction.getEventParams(
                from: event,
                context: context
            )

            guard AssetConversionSwapBounds.matches(
                event: swap,
                origin: origin,
                receiver: verification.receiver,
                path: verification.path,
                bounds: verification.bounds
            ) else {
                return nil
            }

            return MeasuredSwap(index: index, event: swap)
        }
    }

    func findCollections(
        in events: [Event],
        commission: AssetConversionSwapVerification.Commission,
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
