import Foundation
import Operation_iOS

protocol MultistakingRepositoryFactoryProtocol {
    var storageFacade: StorageFacadeProtocol { get }

    func createDashboardRepository(
        for walletId: MetaAccountModel.Id
    ) -> AnyDataProviderRepository<Multistaking.DashboardItem>

    func createDashboardRepository(
        for walletId: MetaAccountModel.Id,
        chainAssetId: ChainAssetId
    ) -> AnyDataProviderRepository<Multistaking.DashboardItem>

    func createResolvedAccountRepository(
    ) -> AnyDataProviderRepository<Multistaking.ResolvedAccount>

    func createOffchainRepository(
    ) -> AnyDataProviderRepository<Multistaking.DashboardItemOffchainPart>

    func createRelaychainRepository(
    ) -> AnyDataProviderRepository<Multistaking.DashboardItemRelaychainPart>

    func createParachainRepository(
    ) -> AnyDataProviderRepository<Multistaking.DashboardItemParachainPart>

    func createNominationPoolsRepository(
    ) -> AnyDataProviderRepository<Multistaking.DashboardItemNominationPoolPart>

    func createMythosRepository(
    ) -> AnyDataProviderRepository<Multistaking.DashboardItemMythosStakingPart>
}

final class MultistakingRepositoryFactory {
    let storageFacade: StorageFacadeProtocol

    init(storageFacade: StorageFacadeProtocol = SubstrateDataStorageFacade.shared) {
        self.storageFacade = storageFacade
    }

    private func createStakingDashboardRepository(
        for filter: NSPredicate
    ) -> AnyDataProviderRepository<Multistaking.DashboardItem> {
        let mapper = StakingDashboardItemMapper()

        let repository = storageFacade.createRepository(
            filter: filter,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        return AnyDataProviderRepository(repository)
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

    func createNominationPoolsRepository(
    ) -> AnyDataProviderRepository<Multistaking.DashboardItemNominationPoolPart> {
        let mapper = StakingDashboardNominationPoolMapper()
        let repository = storageFacade.createRepository(mapper: AnyCoreDataMapper(mapper))
        return AnyDataProviderRepository(repository)
    }

    func createParachainRepository(
    ) -> AnyDataProviderRepository<Multistaking.DashboardItemParachainPart> {
        let mapper = StakingDashboardParachainMapper()
        let repository = storageFacade.createRepository(mapper: AnyCoreDataMapper(mapper))
        return AnyDataProviderRepository(repository)
    }

    func createMythosRepository() -> AnyDataProviderRepository<Multistaking.DashboardItemMythosStakingPart> {
        let mapper = StakingDashboardMythosMapper()
        let repository = storageFacade.createRepository(mapper: AnyCoreDataMapper(mapper))
        return AnyDataProviderRepository(repository)
    }

    func createDashboardRepository(
        for walletId: MetaAccountModel.Id
    ) -> AnyDataProviderRepository<Multistaking.DashboardItem> {
        let filter = NSPredicate(format: "%K == %@", #keyPath(CDStakingDashboardItem.walletId), walletId)
        return createStakingDashboardRepository(for: filter)
    }

    func createDashboardRepository(
        for walletId: MetaAccountModel.Id,
        chainAssetId: ChainAssetId
    ) -> AnyDataProviderRepository<Multistaking.DashboardItem> {
        let filter = NSPredicate.stakingDashboardItem(for: chainAssetId, walletId: walletId)
        return createStakingDashboardRepository(for: filter)
    }
}
