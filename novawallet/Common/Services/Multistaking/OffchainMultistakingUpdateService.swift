import Foundation
import RobinHood

final class OffchainMultistakingUpdateService: BaseSyncService {
    let wallet: MetaAccountModel
    let chainStore: ChainRegistryProtocol
    let accountResolveProvider: AnyDataProvider<Multistaking.ResolvedAccount>
    let dashboardRepository: AnyDataProviderRepository<Multistaking.DashboardItemOffchainPart>
    let operationFactory: MultistakingOffchainOperationFactoryProtocol
    let operationQueue: OperationQueue

    init(
        wallet: MetaAccountModel,
        chainStore: ChainRegistryProtocol,
        accountResolveProvider: AnyDataProvider<Multistaking.ResolvedAccount>,
        dashboardRepository: AnyDataProviderRepository<Multistaking.DashboardItemOffchainPart>,
        operationFactory: MultistakingOffchainOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.wallet = wallet
        self.chainStore = chainStore
        self.accountResolveProvider = accountResolveProvider
        self.dashboardRepository = dashboardRepository
        self.operationFactory = operationFactory
        self.operationQueue = operationQueue
    }
}
