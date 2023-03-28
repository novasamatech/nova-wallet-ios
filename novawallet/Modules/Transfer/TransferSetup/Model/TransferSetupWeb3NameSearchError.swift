import SoraFoundation

enum TransferSetupWeb3NameSearchError: Error {
    typealias Chain = String
    typealias Name = String

    case accountNotFound(Name, Chain)
    case serviceNotFound(Name, Chain)
    case slip44ListIsEmpty
    case kiltService(Error)
    case invalidAddress(Chain)
}

extension TransferSetupWeb3NameSearchError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let title: String
        let message: String
        let strings = R.string.localizable.self
        switch self {
        case let .accountNotFound(name, chain):
            title = strings.transferSetupErrorW3nAccountNotFoundTitle(preferredLanguages: locale?.rLanguages)
            message = strings.transferSetupErrorW3nAccountNotFoundSubtitle(
                KiltW3n.fullName(for: name),
                chain.uppercased(),
                preferredLanguages: locale?.rLanguages
            )
        case let .serviceNotFound(name, chain):
            title = strings.transferSetupErrorW3nServiceNotFoundTitle(preferredLanguages: locale?.rLanguages)
            message = strings.transferSetupErrorW3nServiceNotFoundSubtitle(
                KiltW3n.fullName(for: name),
                chain.uppercased(),
                preferredLanguages: locale?.rLanguages
            )
        case let .invalidAddress(chain):
            title = strings.transferSetupErrorW3nInvalidAddressTitle(preferredLanguages: locale?.rLanguages)
            message = strings.transferSetupErrorW3nInvalidAddressSubtitle(
                chain.uppercased(),
                preferredLanguages: locale?.rLanguages
            )
        default:
            title = strings.transferSetupErrorW3nKiltServiceUnavailableTitle(preferredLanguages: locale?.rLanguages)
            message = strings.transferSetupErrorW3nKiltServiceUnavailableSubtitle(
                preferredLanguages: locale?.rLanguages)
        }

        return ErrorContent(title: title, message: message)
    }
}
