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

extension Multistaking {
    struct SubtensorStakingState: Equatable {
        let positions: [SubtensorStakingPosition]
        let prices: [UInt16: BigUInt]
        let availability: [UInt16: SubtensorStakingPallet.StakeAvailability]
        let unpricedNetuids: Set<UInt16>

        init(
            positions: [SubtensorStakingPosition],
            prices: [UInt16: BigUInt],
            availability: [UInt16: SubtensorStakingPallet.StakeAvailability] = [:],
            unpricedNetuids: Set<UInt16> = []
        ) {
            self.positions = positions
            self.prices = prices
            self.availability = availability
            self.unpricedNetuids = unpricedNetuids
        }

        var totalStakeInRao: BigUInt {
            positions.reduce(BigUInt.zero) { total, position in
                total + (taoValue(of: position) ?? .zero)
            }
        }

        var hasActiveStaking: Bool {
            !positions.isEmpty
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
                unpricedNetuids: unpricedNetuids
            )
        }
    }

    struct DashboardItemSubtensorPart {
        enum MaxApyUpdate: Equatable {
            case keep
            case replace(Decimal?)
        }

        let stakingOption: OptionWithWallet
        let state: SubtensorStakingState
        let maxApy: MaxApyUpdate

        init(stakingOption: OptionWithWallet, state: SubtensorStakingState, maxApy: MaxApyUpdate = .keep) {
            self.stakingOption = stakingOption
            self.state = state
            self.maxApy = maxApy
        }
    }
}

extension Multistaking.DashboardItemOnchainState {
    static func from(subtensorState: Multistaking.SubtensorStakingState) -> Multistaking.DashboardItemOnchainState? {
        subtensorState.hasActiveStaking ? .activeIndependent : nil
    }
}
