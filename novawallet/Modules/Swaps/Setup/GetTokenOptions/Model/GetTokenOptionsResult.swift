import Foundation

enum GetTokenOptionsResult {
    case crosschains([ChainAsset], XcmTransfers)
    case receive(MetaChainAccountResponse)
    case buy([RampAction])
    case changeNow(URL)
}

typealias GetTokenOptionsCompletion = (GetTokenOptionsResult) -> Void
