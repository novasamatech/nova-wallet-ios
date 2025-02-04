import Foundation

struct MythosStakingCommonData {
    let account: MetaChainAccountResponse?
    let chainAsset: ChainAsset?
    let balance: AssetBalance?
    let price: PriceData?
    let collatorsInfo: MythosSessionCollators?
    let totalReward: TotalRewardItem?
    let totalRewardFilter: StakingRewardFiltersPeriod?
    let claimableRewards: MythosStakingClaimableRewards?
}

extension MythosStakingCommonData {
    static var empty: MythosStakingCommonData {
        MythosStakingCommonData(
            account: nil,
            chainAsset: nil,
            balance: nil,
            price: nil,
            collatorsInfo: nil,
            totalReward: nil,
            totalRewardFilter: nil,
            claimableRewards: nil
        )
    }

    func byReplacing(account: MetaChainAccountResponse?) -> MythosStakingCommonData {
        MythosStakingCommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            price: price,
            collatorsInfo: collatorsInfo,
            totalReward: totalReward,
            totalRewardFilter: totalRewardFilter,
            claimableRewards: claimableRewards
        )
    }

    func byReplacing(chainAsset: ChainAsset?) -> MythosStakingCommonData {
        MythosStakingCommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            price: price,
            collatorsInfo: collatorsInfo,
            totalReward: totalReward,
            totalRewardFilter: totalRewardFilter,
            claimableRewards: claimableRewards
        )
    }

    func byReplacing(balance: AssetBalance?) -> MythosStakingCommonData {
        MythosStakingCommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            price: price,
            collatorsInfo: collatorsInfo,
            totalReward: totalReward,
            totalRewardFilter: totalRewardFilter,
            claimableRewards: claimableRewards
        )
    }

    func byReplacing(price: PriceData?) -> MythosStakingCommonData {
        MythosStakingCommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            price: price,
            collatorsInfo: collatorsInfo,
            totalReward: totalReward,
            totalRewardFilter: totalRewardFilter,
            claimableRewards: claimableRewards
        )
    }

    func byReplacing(collatorsInfo: MythosSessionCollators?) -> MythosStakingCommonData {
        MythosStakingCommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            price: price,
            collatorsInfo: collatorsInfo,
            totalReward: totalReward,
            totalRewardFilter: totalRewardFilter,
            claimableRewards: claimableRewards
        )
    }

    func byReplacing(totalReward: TotalRewardItem?) -> MythosStakingCommonData {
        MythosStakingCommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            price: price,
            collatorsInfo: collatorsInfo,
            totalReward: totalReward,
            totalRewardFilter: totalRewardFilter,
            claimableRewards: claimableRewards
        )
    }

    func byReplacing(totalRewardFilter: StakingRewardFiltersPeriod?) -> MythosStakingCommonData {
        MythosStakingCommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            price: price,
            collatorsInfo: collatorsInfo,
            totalReward: totalReward,
            totalRewardFilter: totalRewardFilter,
            claimableRewards: claimableRewards
        )
    }

    func byReplacing(claimableRewards: MythosStakingClaimableRewards?) -> MythosStakingCommonData {
        MythosStakingCommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            price: price,
            collatorsInfo: collatorsInfo,
            totalReward: totalReward,
            totalRewardFilter: totalRewardFilter,
            claimableRewards: claimableRewards
        )
    }
}
