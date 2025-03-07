import Foundation
import Operation_iOS
import BigInt

extension Multistaking {
    struct Option: Hashable {
        let chainAssetId: ChainAssetId
        let type: StakingType

        var stringValue: String {
            "\(chainAssetId.chainId)" + "-" + "\(chainAssetId.assetId)" + "-" + "\(type.rawValue)"
        }
    }

    struct ChainAssetOption: Hashable, Identifiable {
        let chainAsset: ChainAsset
        let type: StakingType

        var option: Option {
            .init(chainAssetId: chainAsset.chainAssetId, type: type)
        }

        var identifier: String { option.stringValue }
    }

    struct OptionWithWallet: Equatable {
        let walletId: MetaAccountModel.Id
        let option: Multistaking.Option

        var stringValue: String {
            "\(walletId)" + "-" + option.stringValue
        }
    }

    struct DashboardItemRelaychainPart {
        let stakingOption: OptionWithWallet
        let state: Multistaking.RelaychainState
    }

    struct DashboardItemParachainPart {
        let stakingOption: OptionWithWallet
        let state: Multistaking.ParachainState
    }

    struct DashboardItemNominationPoolPart {
        let stakingOption: OptionWithWallet
        let state: Multistaking.NominationPoolState?
    }

    struct DashboardItemMythosStakingPart {
        let stakingOption: OptionWithWallet
        let state: Multistaking.MythosStakingState
    }

    struct DashboardItemOffchainPart {
        let stakingOption: OptionWithWallet
        let maxApy: Decimal
        let hasAssignedStake: Bool
        let totalRewards: BigUInt?
    }

    enum DashboardItemOnchainState: String {
        case bonded
        case waiting
        case active // need to consult offchain state for activity
        case activeIndependent // no need to check offchain state for activity

        static func from(relaychainState: Multistaking.RelaychainState) -> DashboardItemOnchainState? {
            guard relaychainState.ledger != nil else {
                return nil
            }

            if let nomination = relaychainState.nomination {
                return nomination.submittedIn >= relaychainState.era.index ? .waiting : .active
            } else if relaychainState.validatorPrefs != nil {
                return .active
            } else {
                return .bonded
            }
        }

        static func from(parachainState: Multistaking.ParachainState) -> DashboardItemOnchainState? {
            guard parachainState.stake != nil else {
                return nil
            }

            if parachainState.shouldHaveActiveCollator {
                return .waiting
            } else {
                return .bonded
            }
        }

        static func from(mythosState: Multistaking.MythosStakingState) -> DashboardItemOnchainState? {
            let hasStakingFreeze = mythosState.freezes?.getMythosStakingAmount() != nil

            guard hasStakingFreeze else {
                return nil
            }

            return mythosState.hasActiveStaking ? .activeIndependent : .bonded
        }

        static func from(nominationPoolState: Multistaking.NominationPoolState) -> DashboardItemOnchainState? {
            guard nominationPoolState.bondedPool?.state == .open else {
                return nil
            }

            guard nominationPoolState.ledger != nil else {
                return nil
            }

            if let nomination = nominationPoolState.nomination, let stateEra = nominationPoolState.era {
                return nomination.submittedIn >= stateEra.index ? .waiting : .active
            } else {
                return .bonded
            }
        }
    }

    struct DashboardItem: Equatable {
        enum State: String, Equatable {
            case active
            case inactive
            case waiting
        }

        let stakingOption: OptionWithWallet
        let onchainState: DashboardItemOnchainState?
        let hasAssignedStake: Bool
        let stake: BigUInt?
        let totalRewards: BigUInt?
        let maxApy: Decimal?

        var hasStaking: Bool {
            stake != nil
        }

        var stakeOrZero: BigUInt {
            stake ?? 0
        }

        var state: State? {
            switch onchainState {
            case .none:
                return nil
            case .bonded:
                return .inactive
            case .waiting:
                guard stakeOrZero > 0 else {
                    return .inactive
                }

                if hasAssignedStake {
                    return .active
                } else {
                    return .waiting
                }
            case .active:
                guard stakeOrZero > 0 else {
                    return .inactive
                }

                if hasAssignedStake {
                    return .active
                } else {
                    return .inactive
                }
            case .activeIndependent:
                return .active
            }
        }
    }

    struct ResolvedAccount: Equatable {
        let stakingOption: Option
        let walletAccountId: AccountId
        let resolvedAccountId: AccountId
        let rewardsAccountId: AccountId?
    }
}

extension ChainModel {
    func getAllStakingChainAssetOptions() -> Set<Multistaking.ChainAssetOption> {
        let stakingOptions = assets.flatMap { asset in
            (asset.stakings ?? []).map { staking in
                Multistaking.ChainAssetOption(
                    chainAsset: .init(chain: self, asset: asset),
                    type: staking
                )
            }
        }

        return Set(stakingOptions)
    }
}
