import Foundation

final class MercuryoOnRampResponseHandler {
    weak var delegate: OnRampHookDelegate?

    var lastTransactionStatus: MercuryoStatus?

    let logger: LoggerProtocol

    init(
        delegate: OnRampHookDelegate,
        logger: LoggerProtocol
    ) {
        self.delegate = delegate
        self.logger = logger
    }
}

extension MercuryoOnRampResponseHandler: OffRampMessageHandling {
    func canHandleMessageOf(name: String) -> Bool {
        name == MercuryoRampEventNames.onBuy.rawValue
    }

    func handle(message: Any, of _: String) {
        do {
            guard let message = "\(message)".data(using: .utf8) else {
                logger.error("Unexpected message: \(message)")
                return
            }

            let buyStatusResponse = try JSONDecoder().decode(
                MercuryoGenericResponse<MercuryoRampResponseData>.self,
                from: message
            )

            guard let data = buyStatusResponse.data else {
                logger.error("Unexpected message: \(message)")
                return
            }

            guard lastTransactionStatus != data.status else {
                return
            }

            lastTransactionStatus = data.status

            switch data.status {
            case .paid:
                delegate?.didFinishOperation()
            default:
                break
            }
        } catch {
            logger.error("Unexpected error: \(error)")
        }
    }
}
