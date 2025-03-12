import Foundation

enum GetTokenOptionsResult {
    case crosschains([ChainAsset], XcmTransfers)
    case receive(MetaChainAccountResponse)
    case buy([RampAction])
}

typealias GetTokenOptionsCompletion = (GetTokenOptionsResult) -> Void
