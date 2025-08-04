protocol MythosStkClaimRewardsViewProtocol: StakingGenericRewardsViewProtocol {
    func didReceiveClaimStrategy(viewModel: StakingClaimRewardsStrategy)
}

protocol MythosStkClaimRewardsInteractorInputProtocol: AnyObject {
    func setup()
    func save(claimStrategy: StakingClaimRewardsStrategy)
    func estimateFee(for model: MythosStkClaimRewardsModel)
    func submit(model: MythosStkClaimRewardsModel)
}

protocol MythosStkClaimRewardsPresenterProtocol: StakingGenericRewardsPresenterProtocol {
    func toggleClaimStrategy()
}

protocol MythosStkClaimRewardsInteractorOutputProtocol: AnyObject {
    func didReceiveAssetBalance(_ balance: AssetBalance?)
    func didReceivePrice(_ price: PriceData?)
    func didReceiveClaimableRewards(_ claimableRewards: MythosStakingClaimableRewards)
    func didReceiveStakingDetails(_ stakingDetails: MythosStakingDetails?)
    func didReceiveAutoCompound(_ autoCompound: Percent?)
    func didReceiveClaimStragegy(_ claimStrategy: StakingClaimRewardsStrategy)
    func didReceiveFeeResult(_ result: Result<ExtrinsicFeeProtocol, Error>)
    func didReceiveSubmissionResult(_ result: Result<ExtrinsicSubmittedModel, Error>)
}

protocol MythosStkClaimRewardsWireframeProtocol: AlertPresentable, ErrorPresentable,
    CommonRetryable, FeeRetryable,
    AddressOptionsPresentable,
    MythosStakingErrorPresentable,
    MessageSheetPresentable,
    ExtrinsicSubmissionPresenting, ExtrinsicSigningErrorHandling {}
