import Foundation

typealias StakingChainsCount = Int

final class StakingRewardsNotificationsWireframe: StakingRewardsNotificationsWireframeProtocol {
    let completion: (Web3Alert.Selection<Set<ChainModel.Id>>?) -> Void

    init(completion: @escaping (Web3Alert.Selection<Set<ChainModel.Id>>?) -> Void) {
        self.completion = completion
    }

    func complete(selectedChains: Web3Alert.Selection<Set<ChainModel.Id>>?) {
        completion(selectedChains)
    }
}
