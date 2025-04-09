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

            let statusChange = try JSONDecoder().decode(MercuryoCallbackBody.self, from: message)
            let statusData = statusChange.data

            logger.debug("New status: \(statusChange)")

            guard statusData.type == MercuryoStatusType.fiatCardSell.rawValue else {
                return
            }

            switch MercuryoStatus(rawValue: statusData.status) {
            case .completed, .succeeded:
                delegate?.didOpenCard()
            case .failed:
                delegate?.didFailToOpenCard()
            case .new, .pending, .paid, nil:
                break
            }

        } catch {
            logger.warning("Not interested message: \(error)")
        }
    }
}
