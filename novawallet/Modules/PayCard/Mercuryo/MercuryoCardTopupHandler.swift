import Foundation

final class MercuryoCardTopupHandler {
    let logger: LoggerProtocol
    let chainAsset: ChainAsset
    weak var delegate: PayCardHookDelegate?

    init(delegate: PayCardHookDelegate, chainAsset: ChainAsset, logger: LoggerProtocol) {
        self.delegate = delegate
        self.chainAsset = chainAsset
        self.logger = logger
    }
}

extension MercuryoCardTopupHandler: PayCardMessageHandling {
    func canHandleMessageOf(name: String) -> Bool {
        name == MercuryoMessageName.onCardTopup.rawValue
    }

    func handle(message: Any, of _: String) {
        do {
            guard let message = "\(message)".data(using: .utf8) else {
                logger.error("Unexpected message: \(message)")
                return
            }

            let transferData = try JSONDecoder().decode(MercuryoTransferData.self, from: message)

            let model = PayCardTopupModel(
                chainAsset: chainAsset,
                amount: transferData.amount.decimalValue,
                recipientAddress: transferData.address
            )

            delegate?.didRequestTopup(from: model)
        } catch {
            logger.error("Unexpected error: \(error)")
        }
    }
}
