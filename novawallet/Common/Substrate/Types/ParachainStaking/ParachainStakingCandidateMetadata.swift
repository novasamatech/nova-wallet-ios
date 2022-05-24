import Foundation
import SubstrateSdk
import BigInt

extension ParachainStaking {
    enum CapacityStatus: Decodable {
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
            switch self {
            case .full:
                return true
            case .partial, .empty:
                return false
            }
        }
    }

    struct CandidateMetadata: Decodable {
        @StringCodable var delegationCount: UInt32
        @StringCodable var lowestTopDelegationAmount: BigUInt
        @StringCodable var lowestBottomDelegationAmount: BigUInt
        let topCapacity: CapacityStatus
        let bottomCapacity: CapacityStatus

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
