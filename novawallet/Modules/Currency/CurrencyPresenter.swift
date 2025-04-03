import Foundation
import Foundation_iOS

final class CurrencyPresenter {
    weak var view: CurrencyViewProtocol?
    private let wireframe: CurrencyWireframeProtocol
    private let interactor: CurrencyInteractorInputProtocol
    private let logger: LoggerProtocol

    private var currentViewModel: [CurrencyViewSectionModel] = []
    private var selectedCurrencyId: Int?
    private var currencies: [Currency] = []

    init(
        interactor: CurrencyInteractorInputProtocol,
        wireframe: CurrencyWireframeProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func convertToViewModel(
        currencies: [Currency],
        selectedCurrency: Int?
    ) -> [CurrencyViewSectionModel] {
        var cryptocurrencyModels: [CurrencyViewSectionModel.CellModel] = []
        var popularFiatModels: [CurrencyViewSectionModel.CellModel] = []
        var fiatModels: [CurrencyViewSectionModel.CellModel] = []

        for currency in currencies {
            let model = CurrencyViewSectionModel.CellModel(
                id: currency.id,
                title: currency.code,
                subtitle: currency.name,
                symbol: currency.symbol ?? currency.code,
                isSelected: currency.id == selectedCurrency
            )
            switch currency.category {
            case .crypto:
                cryptocurrencyModels.append(model)
            case .fiat:
                currency.isPopular ? popularFiatModels.append(model) :
                    fiatModels.append(model)
            }
        }

        let languages = selectedLocale.rLanguages

        return [
            CurrencyViewSectionModel(
                title: R.string.localizable.currencyCategoryCryptocurrencies(preferredLanguages: languages),
                cells: cryptocurrencyModels
            ),
            CurrencyViewSectionModel(
                title: R.string.localizable.currencyCategoryPopularFiat(preferredLanguages: languages),
                cells: popularFiatModels
            ),
            CurrencyViewSectionModel(
                title: R.string.localizable.currencyCategoryFiat(preferredLanguages: languages),
                cells: fiatModels
            )
        ].filter { !$0.cells.isEmpty }
    }

    private func updateView(currencies: [Currency]) {
        self.currencies = currencies

        guard let view = view else {
            return
        }
        currentViewModel = convertToViewModel(
            currencies: currencies,
            selectedCurrency: selectedCurrencyId
        )
        view.currencyListDidLoad(currentViewModel)
    }

    private func updateView(selectedCurrencyId: Int) {
        self.selectedCurrencyId = selectedCurrencyId

        guard let view = view else {
            return
        }
        currentViewModel.updateCells {
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
        guard let currency = currencies.first(where: { $0.id == model.id }) else {
            return
        }
        interactor.set(selectedCurrency: currency)
        wireframe.complete(view: view)
    }
}

// MARK: - CurrencyInteractorOutputProtocol

extension CurrencyPresenter: CurrencyInteractorOutputProtocol {
    func didReceive(currencies: [Currency]) {
        updateView(currencies: currencies)
    }

    func didReceive(selectedCurrency: Currency) {
        updateView(selectedCurrencyId: selectedCurrency.id)
    }

    func didReceive(error: Error) {
        if !wireframe.present(error: error, from: view, locale: selectedLocale) {
            logger.error("Did receive error: \(error)")
        }
    }
}

// MARK: - CurrencyInteractorOutputProtocol

extension CurrencyPresenter: Localizable {
    func applyLocalization() {
        updateView(currencies: currencies)
    }
}
