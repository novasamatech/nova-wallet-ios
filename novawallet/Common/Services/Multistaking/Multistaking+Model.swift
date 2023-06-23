import Foundation
import RobinHood
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
        let stateChange: Multistaking.RelaychainStateChange
    }

    struct DashboardItemParachainPart {
        let stakingOption: OptionWithWallet
        let stateChange: Multistaking.ParachainStateChange
    }

    struct DashboardItemOffchainPart {
        let stakingOption: OptionWithWallet
        let maxApy: Decimal
        let hasAssignedStake: Bool
        let totalRewards: BigUInt?
    }

    struct DashboardItem: Equatable {
        enum State: String, Equatable {
            case active
            case inactive
            case waiting
        }

        let stakingOption: OptionWithWallet
        let hasAssignedStake: Bool
        let expectedOnchain: Bool
        let startedAt: Int64?
        let stake: BigUInt?
        let totalRewards: BigUInt?
        let maxApy: Decimal?

        var state: State? {
            guard stake != nil else {
                // no stake
                return nil
            }

            if startedAt == nil {
                // only bonded but no nominations
                return .inactive
            }

            if hasAssignedStake {
                // have assigned collator/validator
                return .active
            }

            return expectedOnchain ? .inactive : .waiting
        }
    }

    struct ResolvedAccount: Equatable {
        let stakingOption: Option
        let walletAccountId: AccountId
        let resolvedAccountId: AccountId
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
