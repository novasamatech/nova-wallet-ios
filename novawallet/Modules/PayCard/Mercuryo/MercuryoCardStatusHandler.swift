import Foundation

final class MercuryoCardStatusHandler {
    let logger: LoggerProtocol

    init(logger: LoggerProtocol) {
        self.logger = logger
    }
}

extension MercuryoCardStatusHandler: PayCardMessageHandling {
    func canHandleMessageOf(name: String) -> Bool {
        name == MercuryoMessageName.onCardStatusChange.rawValue
    }

    func handle(message: Any, of _: String) {
        logger.debug("On status: \(message)")
    }
}
