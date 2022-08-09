protocol CurrencyViewProtocol: ControllerBackedProtocol {
    func currencyListDidLoad(_ sections: [CurrencyViewSectionModel])
}

protocol CurrencyPresenterProtocol: AnyObject {
    func setup()
    func didSelect(model: CurrencyViewSectionModel.CellModel)
}

protocol CurrencyInteractorInputProtocol: AnyObject {
    func setup()
    func set(selectedCurrency: Currency)
}

protocol CurrencyInteractorOutputProtocol: AnyObject {
    func didReceive(currencies: [Currency])
    func didReceive(selectedCurrency: Currency)
    func didReceive(error: Error)
}

protocol CurrencyWireframeProtocol: ErrorPresentable {}
