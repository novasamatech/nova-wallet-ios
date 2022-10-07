import Foundation

enum ReferendumsInteractorError: Error {
    case settingsLoadFailed
    case priceSubscriptionFailed(_ internalError: Error)
    case balanceSubscriptionFailed(_ internalError: Error)
    case chainSaveFailed(_ internalError: Error)
    case referendumsFetchFailed(_ internalError: Error)
    case blockNumberSubscriptionFailed(_ internalError: Error)
    case metadataSubscriptionFailed(_ internalError: Error)
    case votesFetchFailed(_ internalError: Error)
}
