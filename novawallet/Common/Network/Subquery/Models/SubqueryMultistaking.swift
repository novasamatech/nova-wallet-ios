import Foundation

enum SubqueryMultistaking {
    struct ActiveStaker: Decodable {
        let networkId: String
        let stakingType: String
        let address: String
    }

    struct Apy: Decodable {
        let networkId: String
        let stakingType: String
        let maxApy: Decimal
    }

    struct AccumulatedReward: Decodable {
        let networkId: String
        let stakingType: String
        let amount: String
    }

    struct StatsResponse: Decodable {
        let activeStakers: SubqueryNodes<ActiveStaker>
        let stakingApies: SubqueryNodes<Apy>
        let accumulatedRewards: SubqueryNodes<AccumulatedReward>
    }
}
