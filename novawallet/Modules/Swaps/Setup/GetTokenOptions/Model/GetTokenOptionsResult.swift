import Foundation

enum GetTokenOptionsResult {
    case crosschains([ChainAsset], XcmTransfers)
    case receive(MetaChainAccountResponse)
    case buy([PurchaseAction])
}

typealias GetTokenOptionsCompletion = (GetTokenOptionsResult) -> Void
