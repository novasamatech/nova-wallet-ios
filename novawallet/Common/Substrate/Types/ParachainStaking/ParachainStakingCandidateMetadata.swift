import Foundation
import SubstrateSdk
import BigInt

extension ParachainStaking {
    enum CapacityStatus: Decodable, Equatable {
        case full
        case empty
        case partial

        public init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            let type = try container.decode(String.self)

            switch type {
            case "Full":
                self = .full
            case "Empty":
                self = .empty
            case "Partial":
                self = .partial
            default:
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unexpected type"
                )
            }
        }

        var isFull: Bool {
            self == .full
        }

        var isEmpty: Bool {
            self == .empty
        }
    }

    enum CollatorStatus: Decodable, Equatable {
        case active
        case idle
        case leaving(round: RoundIndex)

        public init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            let type = try container.decode(String.self)

            switch type {
            case "Active":
                self = .active
            case "Idle":
                self = .idle
            case "Leaving":
                let round = try container.decode(StringScaleMapper<RoundIndex>.self).value
                self = .leaving(round: round)
            default:
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unexpected type"
                )
            }
        }
    }

    struct CandidateMetadata: Decodable, Equatable {
        @StringCodable var delegationCount: UInt32
        @StringCodable var lowestTopDelegationAmount: BigUInt
        @StringCodable var lowestBottomDelegationAmount: BigUInt
        @StringCodable var totalCounted: BigUInt
        @StringCodable var bond: BigUInt

        let topCapacity: CapacityStatus
        let bottomCapacity: CapacityStatus
        let status: CollatorStatus

        var isActive: Bool {
            switch status {
            case .active:
                return true
            case .idle, .leaving:
                return false
            }
        }

        func minRewardableStake(for minTechStake: BigUInt) -> BigUInt {
            switch topCapacity {
            case .full:
                return lowestTopDelegationAmount
            case .empty, .partial:
                return minTechStake
            }
        }
    }
}
