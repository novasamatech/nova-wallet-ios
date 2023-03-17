import Foundation

enum EvmRemoteSubscriptionRequest {
    case native(EvmNativeBalanceSubscriptionRequest)
    case erc20Balace(ERC20BalanceSubscriptionRequest)
}

struct ERC20BalanceSubscriptionRequest {
    let holder: AccountAddress
    let contracts: Set<EvmAssetContractId>
    let transactionHistoryUpdater: EvmTransactionHistoryUpdaterProtocol?
}

struct EvmNativeBalanceSubscriptionRequest {
    let holder: AccountAddress
    let assetId: AssetModel.Id
    let transactionHistoryUpdater: EvmTransactionHistoryUpdaterProtocol?
}
