import Foundation
import Operation_iOS

protocol StakingDashboardLocalStorageHandler {
    func handleDashboardItems(
        _ result: Result<[DataProviderChange<Multistaking.DashboardItem>], Error>,
        walletId: MetaAccountModel.Id
    )

    func handleDashboardItems(
        _ result: Result<[DataProviderChange<Multistaking.DashboardItem>], Error>,
        walletId: MetaAccountModel.Id,
        chainAssetId: ChainAssetId
    )
}

extension StakingDashboardLocalStorageHandler {
    func handleDashboardItems(
        _: Result<[DataProviderChange<Multistaking.DashboardItem>], Error>,
        walletId _: MetaAccountModel.Id
    ) {}

    func handleDashboardItems(
        _: Result<[DataProviderChange<Multistaking.DashboardItem>], Error>,
        walletId _: MetaAccountModel.Id,
        chainAssetId _: ChainAssetId
    ) {}
}
