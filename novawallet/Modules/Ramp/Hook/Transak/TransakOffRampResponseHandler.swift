import Foundation

final class TransakOffRampResponseHandler {
    weak var delegate: OffRampHookDelegate?

    let logger: LoggerProtocol
    let chainAsset: ChainAsset

    init(
        delegate: OffRampHookDelegate,
        chainAsset: ChainAsset,
        logger: LoggerProtocol
    ) {
        self.delegate = delegate
        self.chainAsset = chainAsset
        self.logger = logger
    }
}

extension TransakOffRampResponseHandler: OffRampMessageHandling {
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
                MercuryoGenericResponse<MercuryoSellResponseData>.self,
                from: message
            )

            guard let data = sellStatusResponse.data else {
                logger.error("Unexpected message: \(message)")
                return
            }

            switch data.status {
            case .new:
                let model = PayCardTopupModel(
                    chainAsset: chainAsset,
                    amount: data.amounts.request.amount.decimalValue,
                    recipientAddress: data.address
                )

                delegate?.didRequestTransfer(from: model)
            default:
                break
            }
        } catch {
            logger.error("Unexpected error: \(error)")
        }
    }
}
