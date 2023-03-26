import SoraFoundation

enum TransferSetupWeb3NameSearchError: Error {
    case accountNotFound(String)
    case serviceNotFound(String)
    case coinsListIsEmpty
    case kiltService(Error)
}

extension TransferSetupWeb3NameSearchError: ErrorContentConvertible {
    func toErrorContent(for _: Locale?) -> ErrorContent {
        let title: String
        let message: String

        switch self {
        case let .accountNotFound(name):
            title = "Invalid recipient"
            message = "\(name) not found"
        case let .serviceNotFound(name):
            title = "Invalid recipient"
            message = "No valid address was found for \(name) on the KILT network"
        default:
            title = "Error resolving w3n"
            message = "KILT w3n services are unavailable. Try again later or enter the KILT address manually"
        }

        return ErrorContent(title: title, message: message)
    }
}
