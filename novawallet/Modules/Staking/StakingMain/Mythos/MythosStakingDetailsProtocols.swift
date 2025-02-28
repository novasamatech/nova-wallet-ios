protocol MythosStakingDetailsInteractorInputProtocol: AnyObject {
    func setup()
    func update(totalRewardFilter: StakingRewardFiltersPeriod)
}

protocol MythosStakingDetailsInteractorOutputProtocol: AnyObject {
    func didReceiveAccount(_ account: MetaChainAccountResponse?)
    func didReceiveChainAsset(_ chainAsset: ChainAsset?)
    func didReceivePrice(_ price: PriceData?)
    func didReceiveAssetBalance(_ assetBalance: AssetBalance?)
    func didReceiveStakingDetails(_ stakingDetailsState: MythosStakingDetailsState)
    func didReceiveElectedCollators(_ collators: MythosSessionCollators)
    func didReceiveClaimableRewards(_ claimableRewards: MythosStakingClaimableRewards?)
    func didReceiveFrozenBalance(_ frozenBalance: MythosStakingFrozenBalance?)
    func didReceiveReleaseQueue(_ releaseQueue: MythosStakingPallet.ReleaseQueue?)
    func didReceiveBlockNumber(_ blockNumber: BlockNumber)
    func didReceiveStakingDuration(_ stakingDuration: MythosStakingDuration)
    func didReceiveNetworkInfo(_ info: MythosStakingNetworkInfo)
    func didReceiveTotalReward(_ totalReward: TotalRewardItem?)
}

protocol MythosStakingDetailsWireframeProtocol: AlertPresentable, ErrorPresentable,
    MythosStakingErrorPresentable, MythosClaimRewardsPresenting {
    func showStakeTokens(
        from view: ControllerBackedProtocol?,
        initialDetails: MythosStakingDetails?
    )

    func showUnstakeTokens(from view: ControllerBackedProtocol?)

    func showYourCollators(from view: ControllerBackedProtocol?)

    func showRedeemTokens(from view: ControllerBackedProtocol?)
}
