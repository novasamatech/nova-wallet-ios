import Foundation

final class MercuryoCardsResponseHandler {
    let logger: LoggerProtocol

    init(logger: LoggerProtocol) {
        self.logger = logger
    }
}

extension MercuryoCardsResponseHandler: PayCardMessageHandling {
    func canHandleMessageOf(name: String) -> Bool {
        name == MercuryoMessageName.onCardsResponse.rawValue
    }

    func handle(message: Any, of _: String) {
        logger.debug("On cards: \(message)")
    }
}
