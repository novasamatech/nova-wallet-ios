import SoraFoundation

protocol MoonbeamTermsViewProtocol: ControllerBackedProtocol, LoadableViewProtocol, Localizable {
    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>)
}

protocol MoonbeamTermsPresenterProtocol: AnyObject {
    func setup()
    func handleAction()
    func handleLearnTerms()
}

protocol MoonbeamTermsInteractorInputProtocol: AnyObject {
    var termsURL: URL { get }
    func setup()
    func submitAgreement()
    func estimateFee()
}

protocol MoonbeamTermsInteractorOutputProtocol: AnyObject {
    func didReceivePriceData(result: Result<PriceData?, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceiveVerifyRemark(result: Result<Bool, Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
}

protocol MoonbeamTermsWireframeProtocol: WebPresentable,
    StakingErrorPresentable,
    AlertPresentable,
    ErrorPresentable,
    CrowdloanErrorPresentable {
    func showContributionSetup(
        paraId: ParaId,
        moonbeamService: MoonbeamBonusServiceProtocol,
        state: CrowdloanSharedState,
        from view: ControllerBackedProtocol?
    )
}
