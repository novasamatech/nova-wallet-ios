protocol CurrencyViewProtocol: ControllerBackedProtocol {
    func currencyListDidLoad(_ sections: [CurrencyViewSectionModel])
}

protocol CurrencyPresenterProtocol: AnyObject {
    func setup()
    func didSelect(model: CurrencyViewSectionModel.CellModel)
}

protocol CurrencyInteractorInputProtocol: AnyObject {
    func setup()
    func set(selectedCurrencyId: Int)
}

protocol CurrencyInteractorOutputProtocol: AnyObject {
    func didRecieve(currencies: [Currency])
    func didRecieve(selectedCurrency: Currency)
}

protocol CurrencyWireframeProtocol: AnyObject {}
