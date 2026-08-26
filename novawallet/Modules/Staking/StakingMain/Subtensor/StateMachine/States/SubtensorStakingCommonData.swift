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
    /// last positions resync failed and the rendered amounts may be stale (spec §3.2)
    let positionsSyncFailed: Bool
}

private extension SubtensorStakingCommonData {
    func copy(
        account: MetaChainAccountResponse?? = nil,
        chainAsset: ChainAsset?? = nil,
        balance: AssetBalance?? = nil,
        price: PriceData?? = nil,
        claimable: SubtensorRootClaimable?? = nil,
        delegates: [SubtensorDelegate]?? = nil,
        subnetsInfo: SubtensorSubnetsInfo?? = nil,
        networkInfo: SubtensorNetworkInfo?? = nil,
        totalReward: TotalRewardItem?? = nil,
        totalRewardFilter: StakingRewardFiltersPeriod?? = nil,
        positionsSyncFailed: Bool? = nil
    ) -> SubtensorStakingCommonData {
        SubtensorStakingCommonData(
            account: account ?? self.account,
            chainAsset: chainAsset ?? self.chainAsset,
            balance: balance ?? self.balance,
            price: price ?? self.price,
            claimable: claimable ?? self.claimable,
            delegates: delegates ?? self.delegates,
            subnetsInfo: subnetsInfo ?? self.subnetsInfo,
            networkInfo: networkInfo ?? self.networkInfo,
            totalReward: totalReward ?? self.totalReward,
            totalRewardFilter: totalRewardFilter ?? self.totalRewardFilter,
            positionsSyncFailed: positionsSyncFailed ?? self.positionsSyncFailed
        )
    }
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
            totalRewardFilter: nil,
            positionsSyncFailed: false
        )
    }

    func byReplacing(account: MetaChainAccountResponse?) -> SubtensorStakingCommonData {
        copy(account: .some(account))
    }

    func byReplacing(chainAsset: ChainAsset?) -> SubtensorStakingCommonData {
        copy(chainAsset: .some(chainAsset))
    }

    func byReplacing(balance: AssetBalance?) -> SubtensorStakingCommonData {
        copy(balance: .some(balance))
    }

    func byReplacing(price: PriceData?) -> SubtensorStakingCommonData {
        copy(price: .some(price))
    }

    func byReplacing(claimable: SubtensorRootClaimable?) -> SubtensorStakingCommonData {
        copy(claimable: .some(claimable))
    }

    func byReplacing(delegates: [SubtensorDelegate]?) -> SubtensorStakingCommonData {
        copy(delegates: .some(delegates))
    }

    func byReplacing(subnetsInfo: SubtensorSubnetsInfo?) -> SubtensorStakingCommonData {
        copy(subnetsInfo: .some(subnetsInfo))
    }

    func byReplacing(networkInfo: SubtensorNetworkInfo?) -> SubtensorStakingCommonData {
        copy(networkInfo: .some(networkInfo))
    }

    func byReplacing(totalReward: TotalRewardItem?) -> SubtensorStakingCommonData {
        copy(totalReward: .some(totalReward))
    }

    func byReplacing(totalRewardFilter: StakingRewardFiltersPeriod?) -> SubtensorStakingCommonData {
        copy(totalRewardFilter: .some(totalRewardFilter))
    }

    func byReplacing(positionsSyncFailed: Bool) -> SubtensorStakingCommonData {
        copy(positionsSyncFailed: positionsSyncFailed)
    }
}
