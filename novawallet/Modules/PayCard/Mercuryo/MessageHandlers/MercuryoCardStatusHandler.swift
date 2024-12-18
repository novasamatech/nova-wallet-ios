import Foundation

final class MercuryoCardStatusHandler {
    let logger: LoggerProtocol
    weak var delegate: PayCardHookDelegate?

    init(delegate: PayCardHookDelegate, logger: LoggerProtocol) {
        self.delegate = delegate
        self.logger = logger
    }
}

extension MercuryoCardStatusHandler: PayCardMessageHandling {
    func canHandleMessageOf(name: String) -> Bool {
        name == MercuryoMessageName.onCardStatusChange.rawValue
    }

    func handle(message: Any, of _: String) {
        do {
            guard let message = "\(message)".data(using: .utf8) else {
                logger.error("Unexpected message: \(message)")
                return
            }

            let statusChange = try JSONDecoder().decode(MercuryoStatusChange.self, from: message)

            logger.debug("New status: \(statusChange)")

            guard statusChange.type == MercuryoStatusType.fiatCardSell.rawValue else {
                return
            }

            switch MercuryoStatus(rawValue: statusChange.status) {
            case .succeeded:
                delegate?.didOpenCard()
            case .failed:
                delegate?.didFailToOpenCard()
            case .new, .pending, nil:
                break
            }

        } catch {
            logger.error("Unexpected error: \(error)")
        }
    }
}
