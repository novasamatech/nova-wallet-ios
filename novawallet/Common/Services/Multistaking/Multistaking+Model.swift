import Foundation
import BigInt

extension Multistaking {
    struct Option: Hashable {
        let chainAssetId: ChainAssetId
        let type: StakingType

        var stringValue: String {
            "\(chainAssetId.chainId)" + "-" + "\(chainAssetId.assetId)" + "-" + "\(type.rawValue)"
        }
    }

    struct ChainAssetOption: Hashable {
        let chainAsset: ChainAsset
        let type: StakingType

        var option: Option {
            .init(chainAssetId: chainAsset.chainAssetId, type: type)
        }
    }

    struct OptionWithWallet {
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

    struct DashboardItemOffchainPart {
        let stakingOption: OptionWithWallet
        let maxApy: Decimal
        let hasAssignedStake: Bool
        let totalRewards: BigUInt?
    }

    struct DashboardItem {
        // swiftlint:disable:next nesting
        enum State: String {
            case active
            case inactive
            case waiting
        }

        let stakingOption: OptionWithWallet
        let state: State?
        let stake: BigUInt?
        let totalRewards: BigUInt?
        let maxApy: Decimal?
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
