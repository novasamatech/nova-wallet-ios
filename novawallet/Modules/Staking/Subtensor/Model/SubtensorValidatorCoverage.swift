import Foundation

struct SubtensorValidatorCoverage: Equatable {
    let permitted: Int
    let total: Int
    let blockHash: BlockHash

    static func make(
        hotkey: AccountId,
        delegates: [SubtensorStakingPallet.DelegateInfo],
        rows: [SubtensorStakingPallet.DynamicInfo?],
        blockHash: BlockHash
    ) -> Self? {
        let population = rows.compactMap { $0 }
        guard population.count == rows.count,
              Set(population.map(\.netuid)).count == population.count else { return nil }
        let matches = delegates.filter { $0.delegateSs58 == hotkey }
        guard matches.count == 1, let delegate = matches.first else { return nil }
        let netuids = Set(population.map(\.netuid).filter { $0 != SubtensorStakingPallet.rootNetuid })
        let permitted = Set(delegate.validatorPermits.map(\.value).filter { $0 != SubtensorStakingPallet.rootNetuid })
        guard permitted.isSubset(of: netuids) else { return nil }
        return Self(permitted: permitted.count, total: netuids.count, blockHash: blockHash)
    }
}
