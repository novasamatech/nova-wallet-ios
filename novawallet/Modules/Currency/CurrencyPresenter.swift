import Foundation

final class CurrencyPresenter {
    weak var view: CurrencyViewProtocol?
    let wireframe: CurrencyWireframeProtocol
    let interactor: CurrencyInteractorInputProtocol
    private var currencies: [Currency] = []

    init(
        interactor: CurrencyInteractorInputProtocol,
        wireframe: CurrencyWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }

    private static var mapper: ([Currency]) -> [CurrencyViewSectionModel] = { currencies in
        // TODO: localize, reduce code
        var cryptocurrenciesSection = CurrencyViewSectionModel(
            title: "Cryptocurrencies",
            cells: []
        )
        var popularFiatSection = CurrencyViewSectionModel(
            title: "Popular fiat currencies",
            cells: []
        )
        var fiatSection = CurrencyViewSectionModel(
            title: "Fiat currencies",
            cells: []
        )
        for currency in currencies {
            let model = CurrencyRow.Model(
                id: currency.id,
                title: currency.code,
                subtitle: currency.name,
                symbol: currency.symbol ?? "",
                isSelected: false
            )
            switch currency.category {
            case .crypto:
                cryptocurrenciesSection.cells.append(model)
            case .fiat:
                currency.isPopular ? popularFiatSection.cells.append(model) :
                    fiatSection.cells.append(model)
            }
        }

        return [
            cryptocurrenciesSection,
            popularFiatSection,
            fiatSection
        ]
    }

    private func updateView() {
        guard let view = view else {
            return
        }
        view.currencyListDidLoad(Self.mapper(currencies))
    }
}

extension CurrencyPresenter: CurrencyPresenterProtocol {
    func setup() {
        interactor.fetchCurrencies()
        updateView()
    }
}

extension CurrencyPresenter: CurrencyInteractorOutputProtocol {
    func didRecieve(currencies: [Currency]) {
        self.currencies = currencies
        updateView()
    }

    func select(currencyId _: Int) {}
}
