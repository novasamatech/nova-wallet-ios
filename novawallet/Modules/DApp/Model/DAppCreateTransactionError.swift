import Foundation

/**
 *  Failures of the createTransaction signer method. The dApp tells them apart by the name
 *  defined in RFC polkadot-js/api#6213 that the bridge extracts from the "<Name>: <details>" message.
 */
enum DAppCreateTransactionError: Error, Equatable {
    case unsupportedTxExtensionVersion(details: String)
    case missingMandatoryExtension(details: String)
    case decodeError(details: String)
    case invalidHex(details: String)
    case signerUnavailable(details: String)

    var name: String {
        switch self {
        case .unsupportedTxExtensionVersion:
            return "UnsupportedTxExtensionVersion"
        case .missingMandatoryExtension:
            return "MissingMandatoryExtension"
        case .decodeError:
            return "DecodeError"
        case .invalidHex:
            return "InvalidHex"
        case .signerUnavailable:
            return "SignerUnavailable"
        }
    }

    var details: String {
        switch self {
        case let .unsupportedTxExtensionVersion(details),
             let .missingMandatoryExtension(details),
             let .decodeError(details),
             let .invalidHex(details),
             let .signerUnavailable(details):
            return details
        }
    }

    /**
     *  What the dApp receives and what goes to the logs. It may quote values the dApp sent
     *  and is not localized, so the user is shown `toErrorContent(for:)` instead.
     */
    var responseMessage: String {
        "\(name): \(details)"
    }
}

extension DAppCreateTransactionError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        let message = switch self {
        case .signerUnavailable:
            strings.dappConfirmationUnsupportedSigner()
        case .unsupportedTxExtensionVersion, .missingMandatoryExtension, .decodeError, .invalidHex:
            strings.dappConfirmationUnverifiedTransaction()
        }

        return ErrorContent(title: strings.commonErrorGeneralTitle(), message: message)
    }
}
