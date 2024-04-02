import Foundation

typealias StakingChainsCount = Int

final class StakingRewardsNotificationsWireframe: StakingRewardsNotificationsWireframeProtocol {
    let completion: (Web3Alert.Selection<Set<Web3Alert.LocalChainId>>?) -> Void

    init(completion: @escaping (Web3Alert.Selection<Set<Web3Alert.LocalChainId>>?) -> Void) {
        self.completion = completion
    }

    func complete(selectedChains: Web3Alert.Selection<Set<Web3Alert.LocalChainId>>?) {
        completion(selectedChains)
    }
}
