import Foundation
import BigInt
import SubstrateSdk

struct SubtensorStakingPosition: Equatable {
    let hotkey: AccountId
    let netuid: UInt16
    let stakeAlpha: BigUInt
    let isRegistered: Bool
}

extension Multistaking {
    struct SubtensorStakingState: Equatable {
        let positions: [SubtensorStakingPosition]
        let availability: [UInt16: SubtensorStakingPallet.StakeAvailability]
        let rootClaimPreviews: [SubtensorRootClaimPreview]
        let isRootRedeemableStale: Bool

        init(
            positions: [SubtensorStakingPosition],
            availability: [UInt16: SubtensorStakingPallet.StakeAvailability] = [:],
            rootClaimPreviews: [SubtensorRootClaimPreview] = [],
            isRootRedeemableStale: Bool = false
        ) {
            self.positions = positions
            self.availability = availability
            self.rootClaimPreviews = rootClaimPreviews
            self.isRootRedeemableStale = isRootRedeemableStale
        }

        var rootRedeemable: [AccountId: BigUInt] {
            rootClaimPreviews.filter(SubtensorRootClaimRule.isClaimable).reduce(into: [:]) { accum, preview in
                accum[preview.hotkey, default: .zero] += preview.redeemable
            }
        }

        var totalRootRedeemable: BigUInt {
            rootRedeemable.values.reduce(BigUInt.zero, +)
        }

        var hasActiveStaking: Bool {
            !positions.isEmpty || totalRootRedeemable > 0
        }

        var rootStakeInRao: BigUInt? {
            let rootPositions = positions.filter { $0.netuid == SubtensorStakingPallet.rootNetuid }

            guard !rootPositions.isEmpty || totalRootRedeemable > 0 else {
                return nil
            }

            return rootPositions.reduce(BigUInt.zero) { total, position in
                total + position.stakeAlpha
            }
        }

        var heldSubnetNetuids: Set<UInt16> {
            Set(positions.map(\.netuid).filter { $0 != SubtensorStakingPallet.rootNetuid })
        }

        var subnetCount: Int {
            heldSubnetNetuids.count
        }

        func byKeepingRootRedeemable(of previousState: SubtensorStakingState?) -> SubtensorStakingState {
            guard isRootRedeemableStale, let previousState else {
                return self
            }

            return SubtensorStakingState(
                positions: positions,
                availability: availability,
                rootClaimPreviews: previousState.rootClaimPreviews,
                isRootRedeemableStale: true
            )
        }
    }

    struct DashboardItemSubtensorDetails: Equatable {
        let rootStake: BigUInt?
        let subnetCount: Int
        let rootRate: Decimal?
        let subnetRate: Decimal?
        let isFullyPriced: Bool?
    }

    struct DashboardItemSubtensorPart {
        enum MaxApyUpdate: Equatable {
            case keep
            case replace(Decimal?)
        }

        let stakingOption: OptionWithWallet
        let state: SubtensorStakingState
        let stake: BigUInt
        let maxApy: MaxApyUpdate
        let rootRate: Decimal?
        let subnetRate: Decimal?
        let isFullyPriced: Bool?

        var details: DashboardItemSubtensorDetails {
            DashboardItemSubtensorDetails(
                rootStake: state.rootStakeInRao,
                subnetCount: state.subnetCount,
                rootRate: rootRate,
                subnetRate: subnetRate,
                isFullyPriced: isFullyPriced
            )
        }
    }
}

extension Multistaking.DashboardItemSubtensorDetails: Codable {
    private enum CodingKeys: String, CodingKey {
        case rootStake
        case subnetCount
        case rootRate
        case subnetRate
        case isFullyPriced
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        rootStake = try container.decodeIfPresent(StringCodable<BigUInt>.self, forKey: .rootStake)?.wrappedValue
        subnetCount = try container.decode(Int.self, forKey: .subnetCount)
        rootRate = try container.decodeIfPresent(AmountDecimal.self, forKey: .rootRate)?.decimalValue
        subnetRate = try container.decodeIfPresent(AmountDecimal.self, forKey: .subnetRate)?.decimalValue
        isFullyPriced = try container.decodeIfPresent(Bool.self, forKey: .isFullyPriced)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(rootStake.map { StringCodable(wrappedValue: $0) }, forKey: .rootStake)
        try container.encode(subnetCount, forKey: .subnetCount)
        try container.encodeIfPresent(rootRate.map { AmountDecimal(value: $0) }, forKey: .rootRate)
        try container.encodeIfPresent(subnetRate.map { AmountDecimal(value: $0) }, forKey: .subnetRate)
        try container.encodeIfPresent(isFullyPriced, forKey: .isFullyPriced)
    }
}

extension Multistaking.DashboardItemOnchainState {
    static func from(subtensorState: Multistaking.SubtensorStakingState) -> Multistaking.DashboardItemOnchainState? {
        subtensorState.hasActiveStaking ? .activeIndependent : nil
    }
}
