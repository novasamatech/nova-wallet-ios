import Foundation

typealias StakingChainsCount = Int

final class StakingRewardsNotificationsWireframe: StakingRewardsNotificationsWireframeProtocol {
    let completion: (Set<ChainModel.Id>, StakingChainsCount) -> Void

    init(completion: @escaping (Set<ChainModel.Id>, StakingChainsCount) -> Void) {
        self.completion = completion
    }

    func complete(selectedChains: Set<ChainModel.Id>, totalChainsCount: Int) {
        completion(selectedChains, totalChainsCount)
    }
}
