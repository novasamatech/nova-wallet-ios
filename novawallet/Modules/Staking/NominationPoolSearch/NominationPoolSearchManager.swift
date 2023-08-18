import RobinHood

final class NominationPoolSearchManager {
    let viewModels: [StakingSelectPoolViewModel]
    let searchKeysExtractor: (NominationPools.PoolId) -> [String]
    let keyExtractor: (StakingSelectPoolViewModel) -> NominationPools.PoolId

    init(viewModels: [StakingSelectPoolViewModel]) {
        self.viewModels = viewModels

        let mappedModels = viewModels.reduce(
            into: [NominationPools.PoolId: StakingSelectPoolViewModel]()) { result, element in
            result[element.id] = element
        }

        keyExtractor = { stats in
            stats.id
        }

        searchKeysExtractor = { poolId in
            [
                mappedModels[poolId]?.name,
                "\(poolId)"
            ].compactMap { $0 }
        }
    }

    func searchOperation(text: String) -> BaseOperation<[StakingSelectPoolViewModel]> {
        SearchOperationFactory.searchOperation(
            text: text,
            in: viewModels,
            keyExtractor: keyExtractor,
            searchKeysExtractor: searchKeysExtractor
        )
    }
}
