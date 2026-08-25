import Foundation
import BigInt

struct SubtensorStakingPosition: Equatable {
    let hotkey: AccountId
    let netuid: UInt16
    let stakeAlpha: BigUInt
    // StakeInfo.emission is AlphaDividendsPerSubnet[netuid, hotkey] — the hotkey-wide nominator
    // dividend per tempo; scale by stakeAlpha / TotalHotkeyAlpha before showing a per-user rate
    let hotkeyEmissionPerTempo: BigUInt
    let isRegistered: Bool
}

extension Multistaking {
    struct SubtensorStakingState: Equatable {
        let positions: [SubtensorStakingPosition]
        let prices: [UInt16: BigUInt]

        var totalStakeInRao: BigUInt {
            positions.reduce(BigUInt.zero) { total, position in
                guard position.netuid != SubtensorStakingPallet.rootNetuid else {
                    return total + position.stakeAlpha
                }

                let price = prices[position.netuid] ?? .zero

                return total + position.stakeAlpha * price / SubtensorStakingPallet.alphaPriceScale
            }
        }

        var hasActiveStaking: Bool {
            !positions.isEmpty
        }
    }

    struct DashboardItemSubtensorPart {
        let stakingOption: OptionWithWallet
        let state: SubtensorStakingState
    }
}

extension Multistaking.DashboardItemOnchainState {
    static func from(subtensorState: Multistaking.SubtensorStakingState) -> Multistaking.DashboardItemOnchainState? {
        subtensorState.hasActiveStaking ? .activeIndependent : nil
    }
}
