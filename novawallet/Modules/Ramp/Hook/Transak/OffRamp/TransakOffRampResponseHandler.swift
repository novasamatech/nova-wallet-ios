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

        if
            let transferEvent = try? JSONDecoder().decode(
                TransakEvent<TransakTransferEventData>.self,
                from: messageData
            ),
            let transferData = transferEvent.data,
            transferEvent.eventId == .orderCreated {
            switch transferData.status {
            case .awaitingPayment:
                let model = PayCardTopupModel(
                    chainAsset: chainAsset,
                    amount: transferData.cryptoAmount,
                    recipientAddress: transferData.cryptoPaymentData.paymentAddress
                )

                delegate?.didRequestTransfer(from: model)
            }
        } else if
            let transferEvent = try? JSONDecoder().decode(
                TransakEvent<Bool>.self, // for unsuccessful order data is JSONObject
                from: messageData
            ),
            transferEvent.eventId == .widgetClose,
            transferEvent.data == true {
            delegate?.didFinishOperation()
        }
    }
}
