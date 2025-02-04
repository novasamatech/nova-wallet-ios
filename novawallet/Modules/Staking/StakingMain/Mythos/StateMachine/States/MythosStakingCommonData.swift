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
    let releaseQueue: MythosStakingPallet.ReleaseQueue?
    let blockNumber: BlockNumber?
    let blockTime: BlockTime?
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
            claimableRewards: nil,
            releaseQueue: nil,
            blockNumber: nil,
            blockTime: nil
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
            claimableRewards: claimableRewards,
            releaseQueue: releaseQueue,
            blockNumber: blockNumber,
            blockTime: blockTime
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
            claimableRewards: claimableRewards,
            releaseQueue: releaseQueue,
            blockNumber: blockNumber,
            blockTime: blockTime
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
            claimableRewards: claimableRewards,
            releaseQueue: releaseQueue,
            blockNumber: blockNumber,
            blockTime: blockTime
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
            claimableRewards: claimableRewards,
            releaseQueue: releaseQueue,
            blockNumber: blockNumber,
            blockTime: blockTime
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
            claimableRewards: claimableRewards,
            releaseQueue: releaseQueue,
            blockNumber: blockNumber,
            blockTime: blockTime
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
            claimableRewards: claimableRewards,
            releaseQueue: releaseQueue,
            blockNumber: blockNumber,
            blockTime: blockTime
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
            claimableRewards: claimableRewards,
            releaseQueue: releaseQueue,
            blockNumber: blockNumber,
            blockTime: blockTime
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
            claimableRewards: claimableRewards,
            releaseQueue: releaseQueue,
            blockNumber: blockNumber,
            blockTime: blockTime
        )
    }

    func byReplacing(releaseQueue: MythosStakingPallet.ReleaseQueue?) -> MythosStakingCommonData {
        MythosStakingCommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            price: price,
            collatorsInfo: collatorsInfo,
            totalReward: totalReward,
            totalRewardFilter: totalRewardFilter,
            claimableRewards: claimableRewards,
            releaseQueue: releaseQueue,
            blockNumber: blockNumber,
            blockTime: blockTime
        )
    }

    func byReplacing(blockNumber: BlockNumber?) -> MythosStakingCommonData {
        MythosStakingCommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            price: price,
            collatorsInfo: collatorsInfo,
            totalReward: totalReward,
            totalRewardFilter: totalRewardFilter,
            claimableRewards: claimableRewards,
            releaseQueue: releaseQueue,
            blockNumber: blockNumber,
            blockTime: blockTime
        )
    }

    func byReplacing(blockTime: BlockTime?) -> MythosStakingCommonData {
        MythosStakingCommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            price: price,
            collatorsInfo: collatorsInfo,
            totalReward: totalReward,
            totalRewardFilter: totalRewardFilter,
            claimableRewards: claimableRewards,
            releaseQueue: releaseQueue,
            blockNumber: blockNumber,
            blockTime: blockTime
        )
    }
}
