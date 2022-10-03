import Foundation

enum ReferendumsInteractorError: Error {
    case settingsLoadFailed
    case priceSubscriptionFailed(_ internalError: Error)
    case balanceSubscriptionFailed(_ internalError: Error)
    case chainSaveFailed(_ internalError: Error)
}
