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
    let duration: MythosStakingDuration?
    let networkInfo: MythosStakingNetworkInfo?
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
            duration: nil,
            networkInfo: nil
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
            duration: duration,
            networkInfo: networkInfo
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
            duration: duration,
            networkInfo: networkInfo
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
            duration: duration,
            networkInfo: networkInfo
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
            duration: duration,
            networkInfo: networkInfo
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
            duration: duration,
            networkInfo: networkInfo
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
            duration: duration,
            networkInfo: networkInfo
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
            duration: duration,
            networkInfo: networkInfo
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
            duration: duration,
            networkInfo: networkInfo
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
            duration: duration,
            networkInfo: networkInfo
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
            duration: duration,
            networkInfo: networkInfo
        )
    }

    func byReplacing(duration: MythosStakingDuration?) -> MythosStakingCommonData {
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
            duration: duration,
            networkInfo: networkInfo
        )
    }

    func byReplacing(networkInfo: MythosStakingNetworkInfo?) -> MythosStakingCommonData {
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
            duration: duration,
            networkInfo: networkInfo
        )
    }
}
