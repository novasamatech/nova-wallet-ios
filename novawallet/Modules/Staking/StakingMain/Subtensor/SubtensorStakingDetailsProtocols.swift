import Foundation

protocol SubtensorStakingDetailsInteractorInputProtocol: AnyObject {
    func setup()
    func update(totalRewardFilter: StakingRewardFiltersPeriod)
    func retryPositionsSync()
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
    func didReceiveSyncFailure(_ isFailed: Bool)
}

protocol SubtensorStakingDetailsWireframeProtocol: AlertPresentable, ErrorPresentable,
    CommonRetryable, MessageSheetPresentable, SubtensorClaimRewardsPresenting {
    func showPortfolio(
        from view: ControllerBackedProtocol?,
        stakingState: Multistaking.SubtensorStakingState,
        commonData: SubtensorStakingCommonData
    ) -> Bool
    func showStakeTokens(
        from view: ControllerBackedProtocol?,
        initialPosition: SubtensorStakingPosition?
    )

    func showUnstakeTokens(
        from view: ControllerBackedProtocol?,
        initialPosition: SubtensorStakingPosition?
    )

    func showPositionList(
        from view: ControllerBackedProtocol?,
        viewModels: [AccountDetailsPickerViewModel],
        showsCompoundingNote: Bool
    )

    func showUnstakePositionSelection(
        from view: ControllerBackedProtocol?,
        viewModels: [AccountDetailsPickerViewModel],
        delegate: ModalPickerViewControllerDelegate,
        context: AnyObject?
    )
}
