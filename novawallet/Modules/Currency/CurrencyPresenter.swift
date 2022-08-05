import Foundation
import SoraFoundation

final class CurrencyPresenter {
    weak var view: CurrencyViewProtocol?
    let wireframe: CurrencyWireframeProtocol
    let interactor: CurrencyInteractorInputProtocol
    private var currentViewModel: [CurrencyViewSectionModel] = []
    private var selectedCurrencyId: Int?
    private var currencies: [Currency] = []

    init(
        interactor: CurrencyInteractorInputProtocol,
        wireframe: CurrencyWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }

    private static var mapper: ([Currency], Int?) -> [CurrencyViewSectionModel] = { currencies, selected in
        var cryptocurrencyModels: [CurrencyViewSectionModel.CellModel] = []
        var popularFiatModels: [CurrencyViewSectionModel.CellModel] = []
        var fiatModels: [CurrencyViewSectionModel.CellModel] = []

        for currency in currencies {
            let model = CurrencyViewSectionModel.CellModel(
                id: currency.id,
                title: currency.code,
                subtitle: currency.name,
                symbol: currency.symbol ?? "",
                isSelected: currency.id == selected
            )
            switch currency.category {
            case .crypto:
                cryptocurrencyModels.append(model)
            case .fiat:
                currency.isPopular ? popularFiatModels.append(model) :
                    fiatModels.append(model)
            }
        }

        return [
            CurrencyViewSectionModel(
                title: R.string.localizable.currencyCategoryCryptocurrencies(),
                cells: cryptocurrencyModels
            ),
            CurrencyViewSectionModel(
                title: R.string.localizable.currencyCategoryPopularFiat(),
                cells: popularFiatModels
            ),
            CurrencyViewSectionModel(
                title: R.string.localizable.currencyCategoryFiat(),
                cells: fiatModels
            )
        ].filter { !$0.cells.isEmpty }
    }

    private func updateView(currencies: [Currency]) {
        guard let view = view else {
            return
        }
        currentViewModel = Self.mapper(currencies, selectedCurrencyId)
        view.currencyListDidLoad(currentViewModel)
    }

    private func updateView(selectedCurrencyId: Int) {
        self.selectedCurrencyId = selectedCurrencyId

        guard let view = view else {
            return
        }
        currentViewModel.updateCells { [selectedCurrencyId] in
            $0.isSelected = selectedCurrencyId == $0.id
        }

        view.currencyListDidLoad(currentViewModel)
    }
}

// MARK: - CurrencyPresenterProtocol

extension CurrencyPresenter: CurrencyPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func didSelect(model: CurrencyViewSectionModel.CellModel) {
        interactor.set(selectedCurrencyId: model.id)
    }
}

// MARK: - CurrencyInteractorOutputProtocol

extension CurrencyPresenter: CurrencyInteractorOutputProtocol {
    func didRecieve(currencies: [Currency]) {
        updateView(currencies: currencies)
    }

    func didRecieve(selectedCurrency: Currency) {
        updateView(selectedCurrencyId: selectedCurrency.id)
    }
}

// MARK: - CurrencyInteractorOutputProtocol

extension CurrencyPresenter: Localizable {
    func applyLocalization() {
        updateView(currencies: currencies)
    }
}
