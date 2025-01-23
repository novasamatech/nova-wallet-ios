import BigInt

protocol MythosStakingSetupInteractorInputProtocol: AnyObject {
    func setup()
    func applyCollator(with accountId: AccountId)
    func estimateFee(with model: MythosStakeModel)
}

protocol MythosStakingSetupInteractorOutputProtocol: AnyObject {
    func didReceiveAssetBalance(_ balance: AssetBalance?)
    func didReceivePrice(_ priceData: PriceData?)
    func didReceiveFee(_ fee: ExtrinsicFeeProtocol)
    func didReceiveRewardCalculator(_ calculator: CollatorStakingRewardCalculatorEngineProtocol)
    func didReceiveMinStakeAmount(_ amount: BigUInt)
    func didReceiveMaxCollatorsPerStaker(_ maxCollatorsPerStaker: UInt32)
    func didReceiveDetails(_ details: MythosStakingDetails?)
    func didReceiveCandidateInfo(_ info: MythosStakingPallet.CandidateInfo?)
    func didReceiveDelegationIdentities(_ identities: [AccountId: AccountIdentity]?)
    func didReceiveBlockNumber(_ blockNumber: BlockNumber)
    func didReceivePreferredCollator(_ collator: DisplayAddress?)
    func didReceiveFrozenBalance(_ frozenBalance: MythosStakingFrozenBalance)
    func didReceiveError(_ error: MythosStakingSetupError)
}

protocol MythosStakingSetupWireframeProtocol: AlertPresentable, ErrorPresentable, FeeRetryable,
    CollatorStakingDelegationSelectable {
    func showConfirmation(
        from view: CollatorStakingSetupViewProtocol?,
        model: MythosStakeModel,
        initialDelegator: MythosStakingDetails?
    )

    func showCollatorSelection(
        from view: CollatorStakingSetupViewProtocol?,
        delegate: ParaStkSelectCollatorsDelegate
    )
}

enum MythosStakingSetupError: Error {
    case feeFailed(Error)
}
