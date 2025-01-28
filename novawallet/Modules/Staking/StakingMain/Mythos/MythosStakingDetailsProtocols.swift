protocol MythosStakingDetailsInteractorInputProtocol: AnyObject {
    func setup()
    func update(totalRewardFilter: StakingRewardFiltersPeriod)
}

protocol MythosStakingDetailsInteractorOutputProtocol: AnyObject {
    func didReceiveAccount(_ account: MetaChainAccountResponse?)
    func didReceiveChainAsset(_ chainAsset: ChainAsset?)
    func didReceivePrice(_ price: PriceData?)
    func didReceiveAssetBalance(_ assetBalance: AssetBalance?)
    func didReceiveStakingDetails(_ stakingDetails: MythosStakingDetails?)
    func didReceiveElectedCollators(_ collators: MythosSessionCollators)
    func didReceiveClaimableRewards(_ claimableRewards: MythosStakingClaimableRewards?)
    func didReceiveFrozenBalance(_ frozenBalance: MythosStakingFrozenBalance?)
    func didReceiveTotalReward(_ totalReward: TotalRewardItem?)
}

protocol MythosStakingDetailsWireframeProtocol: AnyObject {}
