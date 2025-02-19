import Foundation

final class AssetPriceChartPresenter {
    weak var view: AssetPriceChartViewProtocol?
    weak var moduleOutput: AssetPriceChartModuleOutputProtocol?

    let wireframe: AssetPriceChartWireframeProtocol
    let interactor: AssetPriceChartInteractorInputProtocol
    let assetModel: AssetModel

    private let viewModelFactory: AssetPriceChartViewModelFactoryProtocol

    private var locale: Locale

    init(
        interactor: AssetPriceChartInteractorInputProtocol,
        wireframe: AssetPriceChartWireframeProtocol,
        assetModel: AssetModel,
        viewModelFactory: AssetPriceChartViewModelFactoryProtocol,
        locale: Locale
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.assetModel = assetModel
        self.viewModelFactory = viewModelFactory
        self.locale = locale
    }
}

// MARK: Private

private extension AssetPriceChartPresenter {
    func provideViewModel() {
        let viewModel = viewModelFactory.createViewModel(
            for: assetModel,
            locale: locale
        )

        view?.update(with: viewModel)
    }
}

// MARK: AssetPriceChartPresenterProtocol

extension AssetPriceChartPresenter: AssetPriceChartPresenterProtocol {
    func setup() {
        interactor.setup()

        provideViewModel()
    }
}

// MARK: AssetPriceChartInteractorOutputProtocol

extension AssetPriceChartPresenter: AssetPriceChartInteractorOutputProtocol {
    func didReceive(_ error: Error) {
        moduleOutput?.didReceive(error)
    }
}

// MARK: AssetPriceChartModuleInputProtocol

extension AssetPriceChartPresenter: AssetPriceChartModuleInputProtocol {
    func updateLocale(_ newLocale: Locale) {
        locale = newLocale

        provideViewModel()
    }
}
