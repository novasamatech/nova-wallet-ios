import SoraFoundation

protocol MoonbeamTermsViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>)
}

protocol MoonbeamTermsPresenterProtocol: AnyObject {
    func setup()
    func submitAgreement()
    func handleLearnTerms()
}

protocol MoonbeamTermsInteractorInputProtocol: AnyObject {
    var termsURL: URL { get }
    func setup()
}

protocol MoonbeamTermsInteractorOutputProtocol: AnyObject {
    func didReceivePriceData(result: Result<PriceData?, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
}

protocol MoonbeamTermsWireframeProtocol: WebPresentable {}
