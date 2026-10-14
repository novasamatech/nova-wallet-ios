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
