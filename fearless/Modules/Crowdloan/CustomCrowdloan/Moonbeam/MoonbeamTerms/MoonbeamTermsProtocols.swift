import SoraFoundation

protocol MoonbeamTermsViewProtocol: ControllerBackedProtocol {
    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>)
}

protocol MoonbeamTermsPresenterProtocol: AnyObject {
    func setup()
}

protocol MoonbeamTermsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol MoonbeamTermsInteractorOutputProtocol: AnyObject {
    func didReceivePriceData(result: Result<PriceData?, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
}

protocol MoonbeamTermsWireframeProtocol: AnyObject {}
