import Foundation
import RobinHood

protocol MultistakingRepositoryFactoryProtocol {
    var storageFacade: StorageFacadeProtocol { get }

    func createDashboardRepository(for walletId: MetaAccountModel.Id) -> AnyDataProviderRepository<Multistaking.DashboardItem>

    func createResolvedAccountRepository(
    ) -> AnyDataProviderRepository<Multistaking.ResolvedAccount>

    func createOffchainRepository(
    ) -> AnyDataProviderRepository<Multistaking.DashboardItemOffchainPart>

    func createRelaychainRepository(
    ) -> AnyDataProviderRepository<Multistaking.DashboardItemRelaychainPart>

    func createParachainRepository(
    ) -> AnyDataProviderRepository<Multistaking.DashboardItemParachainPart>
}

final class MultistakingRepositoryFactory {
    let storageFacade: StorageFacadeProtocol

    init(storageFacade: StorageFacadeProtocol = SubstrateDataStorageFacade.shared) {
        self.storageFacade = storageFacade
    }
}

extension MultistakingRepositoryFactory: MultistakingRepositoryFactoryProtocol {
    func createResolvedAccountRepository(
    ) -> AnyDataProviderRepository<Multistaking.ResolvedAccount> {
        let mapper = StakingResolvedAccountMapper()
        let repository = storageFacade.createRepository(mapper: AnyCoreDataMapper(mapper))
        return AnyDataProviderRepository(repository)
    }

    func createOffchainRepository(
    ) -> AnyDataProviderRepository<Multistaking.DashboardItemOffchainPart> {
        let mapper = StakingDashboardOffchainMapper()
        let repository = storageFacade.createRepository(mapper: AnyCoreDataMapper(mapper))
        return AnyDataProviderRepository(repository)
    }

    func createRelaychainRepository(
    ) -> AnyDataProviderRepository<Multistaking.DashboardItemRelaychainPart> {
        let mapper = StakingDashboardRelaychainMapper()
        let repository = storageFacade.createRepository(mapper: AnyCoreDataMapper(mapper))
        return AnyDataProviderRepository(repository)
    }

    func createParachainRepository(
    ) -> AnyDataProviderRepository<Multistaking.DashboardItemParachainPart> {
        let mapper = StakingDashboardParachainMapper()
        let repository = storageFacade.createRepository(mapper: AnyCoreDataMapper(mapper))
        return AnyDataProviderRepository(repository)
    }

    func createDashboardRepository(
        for walletId: MetaAccountModel.Id
    ) -> AnyDataProviderRepository<Multistaking.DashboardItem> {
        let mapper = StakingDashboardItemMapper()

        let filter = NSPredicate(format: "%K == %@", #keyPath(CDStakingDashboardItem.walletId), walletId)
        let repository = storageFacade.createRepository(
            filter: filter,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        return AnyDataProviderRepository(repository)
    }
}
