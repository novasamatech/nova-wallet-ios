import Foundation
import RobinHood

protocol StakingDashboardLocalStorageHandler {
    func handleDashboardItems(
        _ result: Result<[DataProviderChange<Multistaking.DashboardItem>], Error>,
        walletId: MetaAccountModel.Id
    )
}

extension StakingDashboardLocalStorageHandler {
    func handleDashboardItems(
        _: Result<[DataProviderChange<Multistaking.DashboardItem>], Error>,
        walletId _: MetaAccountModel.Id
    ) {}
}
