import Foundation

protocol ExternalAssetBalanceServiceFactoryProtocol {
    func createAutomaticSyncServices(for chainAsset: ChainAsset, accountId: AccountId) -> [SyncServiceProtocol]
    func createPollingSyncServices(for chainAsset: ChainAsset, accountId: AccountId) -> [SyncServiceProtocol]
}
