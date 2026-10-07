import Foundation
import BigInt

struct SubtensorStakingPosition: Equatable {
    let hotkey: AccountId
    let netuid: UInt16
    let stakeAlpha: BigUInt
    // StakeInfo.emission is AlphaDividendsPerSubnet[netuid, hotkey] — the hotkey-wide nominator
    // dividend per tempo; scale by stakeAlpha / TotalHotkeyAlpha before showing a per-user rate
    let hotkeyEmissionPerTempo: BigUInt
    // TotalHotkeyAlpha[hotkey, netuid], the denominator of that scaling. Nil until the positions
    // subscription has delivered it, which is one refresh behind the first state fetch
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
        let prices: [UInt16: BigUInt]
        let availability: [UInt16: SubtensorStakingPallet.StakeAvailability]
        let unpricedNetuids: Set<UInt16>
        let rootRedeemable: [AccountId: BigUInt]
        let isRootRedeemableStale: Bool

        init(
            positions: [SubtensorStakingPosition],
            prices: [UInt16: BigUInt],
            availability: [UInt16: SubtensorStakingPallet.StakeAvailability] = [:],
            unpricedNetuids: Set<UInt16> = [],
            rootRedeemable: [AccountId: BigUInt] = [:],
            isRootRedeemableStale: Bool = false
        ) {
            self.positions = positions
            self.prices = prices
            self.availability = availability
            self.unpricedNetuids = unpricedNetuids
            self.rootRedeemable = rootRedeemable
            self.isRootRedeemableStale = isRootRedeemableStale
        }

        var rootRedeemableError: SubtensorStakingStateError? {
            isRootRedeemableStale ? .staleRootRedeemable : nil
        }

        var totalRootRedeemable: BigUInt {
            rootRedeemable.values.reduce(BigUInt.zero, +)
        }

        var totalStakeInRao: BigUInt {
            let positionsStake = positions.reduce(BigUInt.zero) { total, position in
                total + (taoValue(of: position) ?? .zero)
            }

            return positionsStake + totalRootRedeemable
        }

        var hasActiveStaking: Bool {
            !positions.isEmpty || totalRootRedeemable > 0
        }

        var rootStakeInRao: BigUInt? {
            let rootPositions = positions.filter { $0.netuid == SubtensorStakingPallet.rootNetuid }

            guard !rootPositions.isEmpty || totalRootRedeemable > 0 else {
                return nil
            }

            return rootPositions.reduce(totalRootRedeemable) { total, position in
                total + position.stakeAlpha
            }
        }

        var subnetCount: Int {
            Set(positions.map(\.netuid).filter { $0 != SubtensorStakingPallet.rootNetuid }).count
        }

        func taoValue(of position: SubtensorStakingPosition) -> BigUInt? {
            guard position.netuid != SubtensorStakingPallet.rootNetuid else {
                return position.stakeAlpha
            }

            guard
                !unpricedNetuids.contains(position.netuid),
                let price = prices[position.netuid],
                price > 0 else {
                return nil
            }

            return position.stakeAlpha * price / SubtensorStakingPallet.alphaPriceScale
        }

        func byReplacing(positions: [SubtensorStakingPosition]) -> SubtensorStakingState {
            SubtensorStakingState(
                positions: positions,
                prices: prices,
                availability: availability,
                unpricedNetuids: unpricedNetuids,
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
                prices: prices,
                availability: availability,
                unpricedNetuids: unpricedNetuids,
                rootRedeemable: previousState.rootRedeemable,
                isRootRedeemableStale: true
            )
        }
    }

    struct DashboardItemSubtensorDetails: Equatable {
        let rootStake: BigUInt?
        let subnetCount: Int
        let rootRate: Decimal?
    }

    struct DashboardItemSubtensorPart {
        enum MaxApyUpdate: Equatable {
            case keep
            case replace(Decimal?)
        }

        let stakingOption: OptionWithWallet
        let state: SubtensorStakingState
        let maxApy: MaxApyUpdate
        let rootRate: Decimal?

        init(
            stakingOption: OptionWithWallet,
            state: SubtensorStakingState,
            maxApy: MaxApyUpdate = .keep,
            rootRate: Decimal? = nil
        ) {
            self.stakingOption = stakingOption
            self.state = state
            self.maxApy = maxApy
            self.rootRate = rootRate
        }
    }
}

extension Multistaking.DashboardItemOnchainState {
    static func from(subtensorState: Multistaking.SubtensorStakingState) -> Multistaking.DashboardItemOnchainState? {
        subtensorState.hasActiveStaking ? .activeIndependent : nil
    }
}
