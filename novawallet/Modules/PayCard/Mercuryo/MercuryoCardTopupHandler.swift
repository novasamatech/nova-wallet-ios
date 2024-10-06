import Foundation

final class MercuryoCardTopupHandler {
    let logger: LoggerProtocol

    init(logger: LoggerProtocol) {
        self.logger = logger
    }
}

extension MercuryoCardTopupHandler: PayCardMessageHandling {
    func canHandleMessageOf(name: String) -> Bool {
        name == MercuryoMessageName.onCardTopup.rawValue
    }

    func handle(message: Any, of _: String) {
        logger.debug("On card topup: \(message)")
    }
}
