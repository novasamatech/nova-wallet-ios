import Foundation

final class TransakOnRampResponseHandler {
    weak var delegate: OnRampHookDelegate?

    let logger: LoggerProtocol

    init(
        delegate: OnRampHookDelegate,
        logger: LoggerProtocol
    ) {
        self.delegate = delegate
        self.logger = logger
    }
}

extension TransakOnRampResponseHandler: OffRampMessageHandling {
    func canHandleMessageOf(name: String) -> Bool {
        name == TransakRampEventNames.webViewEventsName.rawValue
    }

    func handle(message: Any, of _: String) {
        guard
            let messageData = "\(message)".data(using: .utf8)
        else {
            logger.error("Unexpected message: \(message)")
            return
        }

        do {
            let transferEvent = try JSONDecoder().decode(
                TransakEvent.self,
                from: messageData
            )

            guard case let .widgetClose(data) = transferEvent, data == true else {
                return
            }

            delegate?.didFinishOperation()
        } catch {
            logger.error("Unexpected error: \(error)")
        }
    }
}
