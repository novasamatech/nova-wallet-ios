import Foundation

struct SubtensorStakingCommonData {
    let account: MetaChainAccountResponse?
    let chainAsset: ChainAsset?
    let balance: AssetBalance?
    let price: PriceData?
    let claimable: SubtensorRootClaimable?
    let delegates: [SubtensorDelegate]?
    let subnetsInfo: SubtensorSubnetsInfo?
    let networkInfo: SubtensorNetworkInfo?
    let totalReward: TotalRewardItem?
    let totalRewardFilter: StakingRewardFiltersPeriod?
}

extension SubtensorStakingCommonData {
    static var empty: SubtensorStakingCommonData {
        SubtensorStakingCommonData(
            account: nil,
            chainAsset: nil,
            balance: nil,
            price: nil,
            claimable: nil,
            delegates: nil,
            subnetsInfo: nil,
            networkInfo: nil,
            totalReward: nil,
            totalRewardFilter: nil
        )
    }

    func byReplacing(account: MetaChainAccountResponse?) -> SubtensorStakingCommonData {
        SubtensorStakingCommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            price: price,
            claimable: claimable,
            delegates: delegates,
            subnetsInfo: subnetsInfo,
            networkInfo: networkInfo,
            totalReward: totalReward,
            totalRewardFilter: totalRewardFilter
        )
    }

    func byReplacing(chainAsset: ChainAsset?) -> SubtensorStakingCommonData {
        SubtensorStakingCommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            price: price,
            claimable: claimable,
            delegates: delegates,
            subnetsInfo: subnetsInfo,
            networkInfo: networkInfo,
            totalReward: totalReward,
            totalRewardFilter: totalRewardFilter
        )
    }

    func byReplacing(balance: AssetBalance?) -> SubtensorStakingCommonData {
        SubtensorStakingCommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            price: price,
            claimable: claimable,
            delegates: delegates,
            subnetsInfo: subnetsInfo,
            networkInfo: networkInfo,
            totalReward: totalReward,
            totalRewardFilter: totalRewardFilter
        )
    }

    func byReplacing(price: PriceData?) -> SubtensorStakingCommonData {
        SubtensorStakingCommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            price: price,
            claimable: claimable,
            delegates: delegates,
            subnetsInfo: subnetsInfo,
            networkInfo: networkInfo,
            totalReward: totalReward,
            totalRewardFilter: totalRewardFilter
        )
    }

    func byReplacing(claimable: SubtensorRootClaimable?) -> SubtensorStakingCommonData {
        SubtensorStakingCommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            price: price,
            claimable: claimable,
            delegates: delegates,
            subnetsInfo: subnetsInfo,
            networkInfo: networkInfo,
            totalReward: totalReward,
            totalRewardFilter: totalRewardFilter
        )
    }

    func byReplacing(delegates: [SubtensorDelegate]?) -> SubtensorStakingCommonData {
        SubtensorStakingCommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            price: price,
            claimable: claimable,
            delegates: delegates,
            subnetsInfo: subnetsInfo,
            networkInfo: networkInfo,
            totalReward: totalReward,
            totalRewardFilter: totalRewardFilter
        )
    }

    func byReplacing(subnetsInfo: SubtensorSubnetsInfo?) -> SubtensorStakingCommonData {
        SubtensorStakingCommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            price: price,
            claimable: claimable,
            delegates: delegates,
            subnetsInfo: subnetsInfo,
            networkInfo: networkInfo,
            totalReward: totalReward,
            totalRewardFilter: totalRewardFilter
        )
    }

    func byReplacing(networkInfo: SubtensorNetworkInfo?) -> SubtensorStakingCommonData {
        SubtensorStakingCommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            price: price,
            claimable: claimable,
            delegates: delegates,
            subnetsInfo: subnetsInfo,
            networkInfo: networkInfo,
            totalReward: totalReward,
            totalRewardFilter: totalRewardFilter
        )
    }

    func byReplacing(totalReward: TotalRewardItem?) -> SubtensorStakingCommonData {
        SubtensorStakingCommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            price: price,
            claimable: claimable,
            delegates: delegates,
            subnetsInfo: subnetsInfo,
            networkInfo: networkInfo,
            totalReward: totalReward,
            totalRewardFilter: totalRewardFilter
        )
    }

    func byReplacing(totalRewardFilter: StakingRewardFiltersPeriod?) -> SubtensorStakingCommonData {
        SubtensorStakingCommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            price: price,
            claimable: claimable,
            delegates: delegates,
            subnetsInfo: subnetsInfo,
            networkInfo: networkInfo,
            totalReward: totalReward,
            totalRewardFilter: totalRewardFilter
        )
    }
}
