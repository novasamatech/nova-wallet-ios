import Foundation

final class AssetConversionEventParser {
    let logger: LoggerProtocol

    init(logger: LoggerProtocol) {
        self.logger = logger
    }

    func extractDeposit(from events: [Event], using codingFactory: RuntimeCoderFactoryProtocol) -> Balance? {
        guard let event = events.last else {
            return nil
        }

        do {
            let parsedEvent: AssetConversionPallet.SwapExecutedEvent = try ExtrinsicExtraction.getEventParams(
                from: event,
                context: codingFactory.createRuntimeJsonContext()
            )

            return parsedEvent.amountOut
        } catch {
            logger.error("Event parsing error: \(error)")
            return nil
        }
    }
}
