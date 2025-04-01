import Foundation

final class MercuryoCardsResponseHandler {
    let logger: LoggerProtocol
    weak var delegate: PayCardHookDelegate?

    init(delegate: PayCardHookDelegate, logger: LoggerProtocol) {
        self.delegate = delegate
        self.logger = logger
    }
}

extension MercuryoCardsResponseHandler: PayCardMessageHandling {
    func canHandleMessageOf(name: String) -> Bool {
        name == MercuryoMessageName.onCardsResponse.rawValue
    }

    func handle(message: Any, of _: String) {
        do {
            guard let message = "\(message)".data(using: .utf8) else {
                logger.error("Unexpected message: \(message)")
                return
            }

            let response = try JSONDecoder().decode(
                MercuryoGenericResponse<[MercuryoCard]>.self,
                from: message
            )

            logger.debug("Cards response: \(response)")

            if let cards = response.data, cards.contains(where: { $0.issuedByMercuryo }) {
                delegate?.didOpenCard()
            } else {
                delegate?.didReceiveNoCard()
            }

        } catch {
            logger.error("Unexpected error: \(error)")
        }
    }
}
