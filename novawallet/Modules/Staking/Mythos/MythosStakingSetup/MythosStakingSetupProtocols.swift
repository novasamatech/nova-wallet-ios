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
    func didReceiveMinStakeAmount(_ amount: BigUInt)
    func didReceiveMaxStakersPerCollator(_ maxStakersPerCollator: UInt32)
    func didReceiveMaxCollatorsPerStaker(_ maxCollatorsPerStaker: UInt32)
    func didReceiveDetails(_ details: MythosStakingDetails?)
    func didReceiveCandidateInfo(_ info: MythosStakingPallet.CandidateInfo?)
    func didReceivePreferredCollator(_ collator: DisplayAddress?)
    func didReceiveFrozenBalance(_ frozenBalance: MythosStakingFrozenBalance)
    func didReceiveError(_ error: MythosStakingSetupError)
}

protocol MythosStakingSetupWireframeProtocol: AlertPresentable, ErrorPresentable, FeeRetryable,
    CollatorStakingDelegationSelectable {
    func showConfirmation(
        from view: CollatorStakingSetupViewProtocol?,
        collator: DisplayAddress,
        amount: Decimal,
        initialDelegator: MythosStakingDetails?
    )

    func showCollatorSelection(from view: CollatorStakingSetupViewProtocol?)
}

enum MythosStakingSetupError: Error {
    case feeFailed(Error)
    case preferredCollator(Error)
}
