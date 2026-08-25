import Foundation

protocol SubtensorStakingDetailsInteractorInputProtocol: AnyObject {
    func setup()
    func update(totalRewardFilter: StakingRewardFiltersPeriod)
}

protocol SubtensorStakingDetailsInteractorOutputProtocol: AnyObject {
    func didReceiveAccount(_ account: MetaChainAccountResponse?)
    func didReceiveChainAsset(_ chainAsset: ChainAsset?)
    func didReceivePrice(_ price: PriceData?)
    func didReceiveAssetBalance(_ assetBalance: AssetBalance?)
    func didReceivePositionsState(_ positionsState: Multistaking.SubtensorStakingState?)
    func didReceiveClaimable(_ claimable: SubtensorRootClaimable?)
    func didReceiveDelegates(_ delegates: [SubtensorDelegate])
    func didReceiveSubnetsInfo(_ subnetsInfo: SubtensorSubnetsInfo)
    func didReceiveNetworkInfo(_ networkInfo: SubtensorNetworkInfo)
    func didReceiveTotalReward(_ totalReward: TotalRewardItem?)
}

protocol SubtensorStakingDetailsWireframeProtocol: AlertPresentable, ErrorPresentable,
    MessageSheetPresentable, SubtensorClaimRewardsPresenting {
    func showStakeTokens(
        from view: ControllerBackedProtocol?,
        initialPosition: SubtensorStakingPosition?
    )

    func showUnstakeTokens(from view: ControllerBackedProtocol?)

    func showPositionList(
        from view: ControllerBackedProtocol?,
        viewModels: [AccountDetailsPickerViewModel]
    )
}
