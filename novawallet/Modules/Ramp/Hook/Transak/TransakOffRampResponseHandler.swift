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
        do {
            guard let message = "\(message)".data(using: .utf8) else {
                logger.error("Unexpected message: \(message)")
                return
            }

            let sellStatusResponse = try JSONDecoder().decode(
                TransakTransferEventData.self,
                from: message
            )

            let model = PayCardTopupModel(
                chainAsset: chainAsset,
                amount: sellStatusResponse.cryptoAmount.decimalValue,
                recipientAddress: sellStatusResponse.walletAddress
            )

            delegate?.didRequestTransfer(from: model)
        } catch {
            logger.error("Unexpected error: \(error)")
        }
    }
}
