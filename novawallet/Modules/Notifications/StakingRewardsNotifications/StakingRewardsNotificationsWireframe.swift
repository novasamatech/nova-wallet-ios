import Foundation

typealias StakingChainsCount = Int

final class StakingRewardsNotificationsWireframe: StakingRewardsNotificationsWireframeProtocol {
    let completion: (Selection<Set<ChainModel.Id>>?) -> Void

    init(completion: @escaping (Selection<Set<ChainModel.Id>>?) -> Void) {
        self.completion = completion
    }

    func complete(selectedChains: Selection<Set<ChainModel.Id>>?) {
        completion(selectedChains)
    }
}
