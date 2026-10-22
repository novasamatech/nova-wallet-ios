import Foundation

extension BittensorApi {
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

    struct Operation: Decodable, Hashable {
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

extension BittensorApi {
    enum PortfolioHistoryPeriod: String, Decodable, Equatable {
        case oneDay = "ONE_DAY"
        case sevenDays = "SEVEN_DAYS"
        case thirtyDays = "THIRTY_DAYS"
        case ninetyDays = "NINETY_DAYS"

        var sampleStep: TimeInterval {
            switch self {
            case .oneDay, .sevenDays:
                return 60 * 60
            case .thirtyDays:
                return 4 * 60 * 60
            case .ninetyDays:
                return 8 * 60 * 60
            }
        }
    }

    struct PortfolioHistoryCollection: Decodable, Equatable {
        struct Components: Decodable, Equatable {
            let portfolioHistory: AvailableComponent
        }

        struct Meta: Decodable, Equatable {
            let completeness: Completeness
            let components: Components
        }

        struct Window: Decodable, Equatable {
            let start: String
            let end: String
        }

        let period: PortfolioHistoryPeriod
        let window: Window
        let points: [PortfolioHistoryPoint]
        let historyScope: String
        let meta: Meta
    }

    struct PortfolioHistoryPoint: Decodable, Equatable {
        let timestamp: String
        let reportedValueTao: String
        let reportedValueUsd: String
        let completed: Bool
    }
}
