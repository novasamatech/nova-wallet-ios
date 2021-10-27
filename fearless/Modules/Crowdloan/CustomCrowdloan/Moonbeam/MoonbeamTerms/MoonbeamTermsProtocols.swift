import SoraFoundation

protocol MoonbeamTermsViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
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
}

protocol MoonbeamTermsInteractorOutputProtocol: AnyObject {
    func didReceivePriceData(result: Result<PriceData?, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceiveVerifyRemark(result: Result<Bool, Error>)
}

protocol MoonbeamTermsWireframeProtocol: WebPresentable {
    func showContributionSetup(
        paraId: ParaId,
        moonbeamService: MoonbeamBonusServiceProtocol,
        state: CrowdloanSharedState,
        from view: ControllerBackedProtocol?
    )
}
