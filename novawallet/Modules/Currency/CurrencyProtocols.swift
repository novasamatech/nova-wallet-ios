protocol CurrencyViewProtocol: ControllerBackedProtocol {
    func currencyListDidLoad(_ sections: [CurrencyViewSectionModel])
}

protocol CurrencyPresenterProtocol: AnyObject {
    func setup()
}

protocol CurrencyInteractorInputProtocol: AnyObject {
    func fetchCurrencies()
}

protocol CurrencyInteractorOutputProtocol: AnyObject {
    func didRecieve(currencies: [Currency])
    func select(currencyId: Int)
}

protocol CurrencyWireframeProtocol: AnyObject {}
