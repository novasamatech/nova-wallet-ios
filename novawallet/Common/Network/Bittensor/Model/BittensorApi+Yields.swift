import Foundation

extension BittensorApi {
    struct AlphaYieldCollection: Decodable, Equatable {
        struct Components: Decodable, Equatable {
            let alphaYield: AvailableComponent
        }

        struct Meta: Decodable, Equatable {
            let completeness: Completeness
            let components: Components
        }

        let items: [AlphaYield]
        let meta: Meta
        let pageInfo: PageInfo
    }

    struct AlphaYield: Decodable, Equatable {
        let metricKind: String
        let netuid: UInt16
        let hotkey: String
        let reportedRate: String
        let sourceTimestamp: String
    }
}
