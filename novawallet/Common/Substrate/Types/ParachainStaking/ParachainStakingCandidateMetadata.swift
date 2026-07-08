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

    struct CandidateMetadata: Equatable {
        let delegationCount: UInt32
        let lowestTopDelegationAmount: BigUInt
        let lowestBottomDelegationAmount: BigUInt
        let totalCounted: BigUInt
        let bond: BigUInt

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

        func isStakeShouldBeActive(for stake: BigUInt) -> Bool {
            !topCapacity.isFull || stake > lowestTopDelegationAmount
        }
    }
}

// MARK: - Decodable (handles both Moonbeam and EWX field names)

extension ParachainStaking.CandidateMetadata: Decodable {
    /// Moonbeam uses `delegation_count`, `lowest_top_delegation_amount`, etc.
    /// EWX (AvN fork) uses `nomination_count`, `lowest_top_nomination_amount`, etc.
    /// The struct layout is identical — only field names differ.
    private enum CodingKeys: String, CodingKey {
        case bond
        case totalCounted
        case topCapacity
        case bottomCapacity
        case status

        // Moonbeam field names
        case delegationCount
        case lowestTopDelegationAmount
        case lowestBottomDelegationAmount

        // EWX (AvN) field names
        case nominationCount
        case lowestTopNominationAmount
        case lowestBottomNominationAmount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        bond = try container.decode(StringScaleMapper<BigUInt>.self, forKey: .bond).value
        totalCounted = try container.decode(StringScaleMapper<BigUInt>.self, forKey: .totalCounted).value
        topCapacity = try container.decode(ParachainStaking.CapacityStatus.self, forKey: .topCapacity)
        bottomCapacity = try container.decode(ParachainStaking.CapacityStatus.self, forKey: .bottomCapacity)
        status = try container.decode(ParachainStaking.CollatorStatus.self, forKey: .status)

        if let count = try? container.decode(StringScaleMapper<UInt32>.self, forKey: .delegationCount) {
            delegationCount = count.value
        } else {
            delegationCount = try container.decode(
                StringScaleMapper<UInt32>.self, forKey: .nominationCount
            ).value
        }

        if let amount = try? container.decode(StringScaleMapper<BigUInt>.self, forKey: .lowestTopDelegationAmount) {
            lowestTopDelegationAmount = amount.value
        } else {
            lowestTopDelegationAmount = try container.decode(
                StringScaleMapper<BigUInt>.self, forKey: .lowestTopNominationAmount
            ).value
        }

        if let amount = try? container.decode(StringScaleMapper<BigUInt>.self, forKey: .lowestBottomDelegationAmount) {
            lowestBottomDelegationAmount = amount.value
        } else {
            lowestBottomDelegationAmount = try container.decode(
                StringScaleMapper<BigUInt>.self, forKey: .lowestBottomNominationAmount
            ).value
        }
    }
}
