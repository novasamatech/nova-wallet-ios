import Foundation
import Operation_iOS

struct SwipeGovRepositoryFactory {
    static func createVotingItemsRepository(
        for chainId: ChainModel.Id,
        metaId: MetaAccountModel.Id,
        using storage: StorageFacadeProtocol
    ) -> AnyDataProviderRepository<VotingBasketItemLocal> {
        let mapper = VotingBasketItemMapper()

        let filter = NSPredicate.votingBasketItems(
            for: chainId,
            metaId: metaId
        )
        let repository = storage.createRepository(
            filter: filter,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        return AnyDataProviderRepository(repository)
    }

    static func createVotingPowerRepository(
        for chainId: ChainModel.Id,
        metaId: MetaAccountModel.Id,
        using storage: StorageFacadeProtocol
    ) -> AnyDataProviderRepository<VotingPowerLocal> {
        let mapper = VotingPowerMapper()

        let filter = NSPredicate.votingPower(
            for: chainId,
            metaId: metaId
        )
        let repository = storage.createRepository(
            filter: filter,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        return AnyDataProviderRepository(repository)
    }
}
