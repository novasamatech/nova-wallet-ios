import Foundation

extension BittensorApi {
    struct RewardCollection: Decodable, Equatable {
        struct Components: Decodable, Equatable {
            let rewardEvents: AvailableComponent
        }

        struct Meta: Decodable, Equatable {
            let completeness: Completeness
            let components: Components
        }

        let items: [Reward]
        let pageInfo: PageInfo
        let historyScope: String
        let meta: Meta
    }

    struct Reward: Decodable, Equatable {
        let sourceTimestamp: UInt64
        let blockNumber: UInt64
        let netuid: UInt16
        let hotkey: String
        let reportedAmount: String
        let reportedPrice: String
    }

    struct OperationCollection: Decodable, Equatable {
        struct Components: Decodable, Equatable {
            let operationHistory: AvailableComponent
        }

        struct Meta: Decodable, Equatable {
            let completeness: Completeness
            let components: Components
        }

        let items: [Operation]
        let pageInfo: PageInfo
        let historyScope: String
        let meta: Meta
    }

    struct Operation: Decodable, Equatable {
        let sourceEventId: String
        let sourceTimestamp: String
        let netuid: UInt16
        let hotkey: String
        let reportedAmountIn: String
        let reportedAmountOut: String
        let reportedPrice: String
        let sourceExtrinsicReference: String
        let sourceOperationType: String?
    }
}
