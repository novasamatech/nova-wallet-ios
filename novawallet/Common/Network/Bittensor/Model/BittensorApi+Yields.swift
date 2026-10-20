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
        static let reliableRate = "RELIABLE"
        static let unreliableRate = "UNRELIABLE"

        let metricKind: String
        let netuid: UInt16
        let hotkey: String
        let reportedRate: String
        let sourceTimestamp: String
        /// The server's verdict on `reportedRate` (ADR-0045): `RELIABLE` or `UNRELIABLE`.
        let rateReliability: String?
        /// Why the rate is not reliable; an open lower-snake-case vocabulary.
        let rateFlags: [String]?

        /// A backend without the verdict keeps the previous behavior; any other value hides the rate.
        var isRateReliable: Bool {
            rateReliability.map { $0 == Self.reliableRate } ?? true
        }
    }

    struct RootValidatorCollection: Decodable, Equatable {
        struct Components: Decodable, Equatable {
            let rootValidators: AvailableComponent
            let stakeYieldWindows: ComponentMetadata
        }

        struct Meta: Decodable, Equatable {
            let completeness: Completeness
            let components: Components
        }

        let items: [RootValidator]
        let meta: Meta
    }

    struct RootValidator: Decodable, Equatable {
        let hotkey: String
        let name: String?
        let rootStakeTao: String?
        let stakeYield: RootStakeYield
    }

    struct RootStakeYield: Decodable, Equatable {
        let d30: RootYieldWindow?
    }

    struct RootYieldWindow: Decodable, Equatable {
        let apy: String
    }

    struct RootOverview: Decodable, Equatable {
        struct Components: Decodable, Equatable {
            let indexes: ComponentMetadata
        }

        struct Meta: Decodable, Equatable {
            let components: Components
        }

        struct StakeIndex: Decodable, Equatable {
            let stakeYield: RootStakeYield
        }

        let meta: Meta
        let stakeIndex: StakeIndex?
    }
}
