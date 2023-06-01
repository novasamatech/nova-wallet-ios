import Foundation

struct MultistakingSyncState: Equatable {
    let isOnchainSyncing: [Multistaking.Option: Bool]
    let isOffchainSyncing: Bool

    init(
        isOnchainSyncing: [Multistaking.Option: Bool] = [:],
        isOffchainSyncing: Bool = false
    ) {
        self.isOnchainSyncing = isOnchainSyncing
        self.isOffchainSyncing = isOffchainSyncing
    }

    func updating(syncing: Bool, stakingOption: Multistaking.Option) -> MultistakingSyncState {
        var onchain = isOnchainSyncing
        onchain[stakingOption] = syncing

        return .init(isOnchainSyncing: onchain, isOffchainSyncing: isOffchainSyncing)
    }

    func updating(isOffchainSyncing: Bool) -> MultistakingSyncState {
        .init(isOnchainSyncing: isOnchainSyncing, isOffchainSyncing: isOffchainSyncing)
    }
}
