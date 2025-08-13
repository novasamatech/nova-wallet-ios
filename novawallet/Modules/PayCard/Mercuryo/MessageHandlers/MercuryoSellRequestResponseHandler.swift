import Foundation

final class MercuryoSellRequestResponseHandler {
    weak var delegate: PayCardHookDelegate?

    var lastTransactionStatus: MercuryoStatus?

    let logger: LoggerProtocol
    let chainAsset: ChainAsset

    init(
        delegate: PayCardHookDelegate,
        chainAsset: ChainAsset,
        logger: LoggerProtocol
    ) {
        self.delegate = delegate
        self.chainAsset = chainAsset
        self.logger = logger
    }
}

extension MercuryoSellRequestResponseHandler: PayCardMessageHandling {
    func canHandleMessageOf(name: String) -> Bool {
        name == MercuryoMessageName.onCardTopup.rawValue
    }

    func handle(message: Any, of _: String) {
        do {
            guard let message = "\(message)".data(using: .utf8) else {
                logger.error("Unexpected message: \(message)")
                return
            }

            let sellStatusResponse = try JSONDecoder().decode(
                MercuryoGenericResponse<MercuryoRampResponseData>.self,
                from: message
            )

            guard let data = sellStatusResponse.data else {
                logger.error("Unexpected message: \(message)")
                return
            }

            guard lastTransactionStatus != data.status else {
                return
            }

            lastTransactionStatus = data.status

            switch data.status {
            case .new:
                let model = PayCardTopupModel(
                    chainAsset: chainAsset,
                    amount: data.amounts.request.amount.decimalValue,
                    recipientAddress: data.address
                )

                delegate?.didRequestTopup(from: model)
            case .pending:
                delegate?.didReceivePendingCardOpen()
            case .completed, .succeeded:
                delegate?.didOpenCard()
            case .failed:
                delegate?.didFailToOpenCard()
            case .paid:
                break
            }
        } catch {
            logger.error("Unexpected error: \(error)")
        }
    }
}
