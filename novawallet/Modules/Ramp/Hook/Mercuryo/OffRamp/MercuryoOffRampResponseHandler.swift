import Foundation

final class MercuryoOffRampResponseHandler {
    weak var delegate: OffRampHookDelegate?

    var lastTransactionStatus: MercuryoStatus?

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

extension MercuryoOffRampResponseHandler: OffRampMessageHandling {
    func canHandleMessageOf(name: String) -> Bool {
        name == MercuryoRampEventNames.onSell.rawValue
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

                delegate?.didRequestTransfer(from: model)
            case .completed:
                delegate?.didFinishOperation()
            default:
                break
            }
        } catch {
            logger.error("Unexpected error: \(error)")
        }
    }
}
