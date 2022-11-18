import Foundation

enum EvmRemoteSubscriptionRequest {
    case erc20Balace(ERC20BalanceSubscriptionRequest)
}

struct ERC20BalanceSubscriptionRequest {
    let holder: AccountAddress
    let contracts: Set<EvmAssetContractId>
}
