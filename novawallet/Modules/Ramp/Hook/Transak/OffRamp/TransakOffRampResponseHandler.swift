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
        name == TransakRampEventNames.webViewEventsName.rawValue
    }

    func handle(message: Any, of _: String) {
        guard
            let messageData = "\(message)".data(using: .utf8)
        else {
            logger.error("Unexpected message: \(message)")
            return
        }

        do {
            let transferEvent = try JSONDecoder().decode(
                TransakEvent.self,
                from: messageData
            )

            switch transferEvent {
            case let .orderCreated(data) where data.status == .awaitingPayment:
                let model = PayCardTopupModel(
                    chainAsset: chainAsset,
                    amount: data.cryptoAmount,
                    recipientAddress: data.cryptoPaymentData.paymentAddress
                )

                delegate?.didRequestTransfer(from: model)
            case let .widgetClose(data) where data == true:
                delegate?.didFinishOperation()
            default:
                break
            }
        } catch {
            logger.error("Unexpected error: \(error)")
        }
    }
}
