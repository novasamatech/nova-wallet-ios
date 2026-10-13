import Foundation
import BigInt

struct SubtensorStakingPosition: Equatable {
    let hotkey: AccountId
    let netuid: UInt16
    let stakeAlpha: BigUInt
    // StakeInfo.emission is AlphaDividendsPerSubnet[netuid, hotkey] — the hotkey-wide nominator
    // dividend per tempo; scale by stakeAlpha / TotalHotkeyAlpha before showing a per-user rate
    let hotkeyEmissionPerTempo: BigUInt
    let totalHotkeyAlpha: BigUInt?
    let isRegistered: Bool

    func byReplacing(totalHotkeyAlpha: BigUInt?) -> SubtensorStakingPosition {
        SubtensorStakingPosition(
            hotkey: hotkey,
            netuid: netuid,
            stakeAlpha: stakeAlpha,
            hotkeyEmissionPerTempo: hotkeyEmissionPerTempo,
            totalHotkeyAlpha: totalHotkeyAlpha,
            isRegistered: isRegistered
        )
    }
}

enum SubtensorStakingStateError: Error {
    case staleRootRedeemable
}

extension Multistaking {
    struct SubtensorStakingState: Equatable {
        let positions: [SubtensorStakingPosition]
        let availability: [UInt16: SubtensorStakingPallet.StakeAvailability]
        let rootRedeemable: [AccountId: BigUInt]
        let isRootRedeemableStale: Bool

        init(
            positions: [SubtensorStakingPosition],
            availability: [UInt16: SubtensorStakingPallet.StakeAvailability] = [:],
            rootRedeemable: [AccountId: BigUInt] = [:],
            isRootRedeemableStale: Bool = false
        ) {
            self.positions = positions
            self.availability = availability
            self.rootRedeemable = rootRedeemable
            self.isRootRedeemableStale = isRootRedeemableStale
        }

        var rootRedeemableError: SubtensorStakingStateError? {
            isRootRedeemableStale ? .staleRootRedeemable : nil
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

        var subnetCount: Int {
            Set(positions.map(\.netuid).filter { $0 != SubtensorStakingPallet.rootNetuid }).count
        }

        func byReplacing(positions: [SubtensorStakingPosition]) -> SubtensorStakingState {
            SubtensorStakingState(
                positions: positions,
                availability: availability,
                rootRedeemable: rootRedeemable,
                isRootRedeemableStale: isRootRedeemableStale
            )
        }

        func byKeepingRootRedeemable(of previousState: SubtensorStakingState?) -> SubtensorStakingState {
            guard isRootRedeemableStale, let previousState else {
                return self
            }

            return SubtensorStakingState(
                positions: positions,
                availability: availability,
                rootRedeemable: previousState.rootRedeemable,
                isRootRedeemableStale: true
            )
        }
    }

    struct DashboardItemSubtensorDetails: Equatable {
        let rootStake: BigUInt?
        let subnetCount: Int
        let rootRate: Decimal?
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
        let isFullyPriced: Bool?

        init(
            stakingOption: OptionWithWallet,
            state: SubtensorStakingState,
            stake: BigUInt,
            maxApy: MaxApyUpdate = .keep,
            rootRate: Decimal? = nil,
            isFullyPriced: Bool? = nil
        ) {
            self.stakingOption = stakingOption
            self.state = state
            self.stake = stake
            self.maxApy = maxApy
            self.rootRate = rootRate
            self.isFullyPriced = isFullyPriced
        }
    }
}

extension Multistaking.DashboardItemOnchainState {
    static func from(subtensorState: Multistaking.SubtensorStakingState) -> Multistaking.DashboardItemOnchainState? {
        subtensorState.hasActiveStaking ? .activeIndependent : nil
    }
}
