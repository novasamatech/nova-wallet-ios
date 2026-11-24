import Foundation

enum EvmTransactionMonitorError: Error {
    case dropped(transactionHash: String)
    case stillPending(transactionHash: String)

    var mayStillLand: Bool {
        switch self {
        case .dropped:
            false
        case .stillPending:
            true
        }
    }
}

extension EvmTransactionMonitorError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        switch self {
        case .dropped:
            return ErrorContent(title: strings.commonErrorGeneralTitle(), message: strings.commonTransactionFailed())
        case .stillPending:
            return ErrorContent(
                title: strings.commonTransactionTakingLongerTitle(),
                message: strings.commonTransactionStillPendingMessage()
            )
        }
    }
}
