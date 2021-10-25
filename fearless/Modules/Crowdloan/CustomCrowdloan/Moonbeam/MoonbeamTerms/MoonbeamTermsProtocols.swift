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
    func didReceiveRemark(result: Result<String, Error>)
}

protocol MoonbeamTermsWireframeProtocol: WebPresentable {}
