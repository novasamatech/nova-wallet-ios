import Foundation

final class AssetsHydraExchangeDepositParser {
    let logger: LoggerProtocol

    init(logger: LoggerProtocol) {
        self.logger = logger
    }

    func extractDeposit(from events: [Event], using codingFactory: RuntimeCoderFactoryProtocol) -> Balance? {
        guard let event = events.last else {
            return nil
        }

        do {
            let codingPath = codingFactory.metadata.createEventCodingPath(from: event)

            switch codingPath {
            case HydraRouter.routeExecutedPath:
                let parsedEvent: HydraRouter.RouteExecutedEvent = try ExtrinsicExtraction.getEventParams(
                    from: event,
                    context: codingFactory.createRuntimeJsonContext()
                )

                return parsedEvent.amountOut
            case HydraOmnipool.sellExecutedPath, HydraOmnipool.buyExecutedPath:
                let parsedEvent: HydraOmnipool.SwapExecuted = try ExtrinsicExtraction.getEventParams(
                    from: event,
                    context: codingFactory.createRuntimeJsonContext()
                )

                return parsedEvent.amountOut
            default:
                return nil
            }
        } catch {
            logger.error("Event parsing error: \(error)")
            return nil
        }
    }
}
