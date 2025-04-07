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
            let messageData = "\(message)".data(using: .utf8),
            let transferEvent = try? JSONDecoder().decode(
                TransakEvent<TransakTransferEventData>.self,
                from: messageData
            )
        else {
            logger.error("Unexpected message: \(message)")
            return
        }

        switch transferEvent.data.status {
        case .awaitingPayment:
            let model = PayCardTopupModel(
                chainAsset: chainAsset,
                amount: transferEvent.data.cryptoAmount,
                recipientAddress: transferEvent.data.cryptoPaymentData.paymentAddress
            )

            delegate?.didRequestTransfer(from: model)
        }
    }
}
