import Foundation
import BigInt
import SubstrateSdk

enum SubqueryMultistaking {
    struct ActiveStaker: Decodable {
        let networkId: String
        let stakingType: String
        let address: String
    }

    struct Apy: Decodable {
        enum CodingKeys: String, CodingKey {
            case networkId
            case stakingType
            case maxApy = "maxAPY"
        }

        let networkId: String
        let stakingType: String
        let maxApy: Decimal
    }

    struct AccumulatedReward: Decodable {
        struct Sum: Decodable {
            let amount: String
        }

        let keys: [String]
        let sum: Sum
    }

    struct NetworkStaking: Hashable {
        let networkId: String
        let stakingType: String
    }
    
    struct NetworkAccountStaking: Hashable {
        let networkId: String
        let accountId: AccountId
        let stakingType: String
    }

    struct StatsResponse: Decodable {
        let activeStakers: SubqueryNodes<ActiveStaker>
        let stakingApies: SubqueryNodes<Apy>
        let rewards: SubqueryAggregates<AccumulatedReward>
        let slashes: SubqueryAggregates<AccumulatedReward>
    }
}
