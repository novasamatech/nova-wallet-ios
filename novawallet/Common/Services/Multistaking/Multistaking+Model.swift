import Foundation
import BigInt

extension Multistaking {
    struct Option {
        let chainAssetId: ChainAssetId
        let type: StakingType
    }

    struct OptionWithWallet {
        let walletId: MetaAccountModel.Id
        let option: Multistaking.Option

        var stringValue: String {
            "\(walletId)" + "-" + "\(option.chainAssetId.chainId)" + "-" +
                "\(option.chainAssetId.assetId)" + "-" + "\(option.type.rawValue)"
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
}
