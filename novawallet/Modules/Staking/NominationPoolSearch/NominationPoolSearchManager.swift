import RobinHood

final class NominationPoolSearchManager {
    let models: [NominationPools.PoolStats]
    let searchKeysExtractor: (NominationPools.PoolId) -> [String]
    let keyExtractor: (NominationPools.PoolStats) -> NominationPools.PoolId

    init(stats: [NominationPools.PoolStats]) {
        models = stats

        let mappedModels = models.reduce(
            into: [NominationPools.PoolId: NominationPools.PoolStats]()) { result, element in
            result[element.poolId] = element
        }

        keyExtractor = { stats in
            stats.poolId
        }

        searchKeysExtractor = { poolId in
            [
                mappedModels[poolId]?.metadata.map { String(data: $0, encoding: .utf8) } ?? nil,
                "\(poolId)"
            ].compactMap { $0 }
        }
    }

    func searchOperation(text: String) -> BaseOperation<[NominationPools.PoolStats]> {
        SearchOperationFactory.searchOperation(
            text: text,
            in: models,
            keyExtractor: keyExtractor,
            searchKeysExtractor: searchKeysExtractor
        )
    }
}
