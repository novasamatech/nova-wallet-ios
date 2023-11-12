import Foundation

enum GetTokenOptionsResult {
    case crosschains(Set<ChainAssetId>)
    case receive(MetaChainAccountResponse)
    case buy([PurchaseAction])
}

typealias GetTokenOptionsCompletion = (GetTokenOptionsResult) -> Void
