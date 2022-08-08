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
    func didRecieve(currencies: [Currency])
    func didRecieve(selectedCurrency: Currency)
    func didRecieve(error: Error)
}

protocol CurrencyWireframeProtocol: ErrorPresentable {}
