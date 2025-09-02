import Foundation
import Foundation_iOS

class AssetOperationNetworkListPresenter {
    weak var view: AssetOperationNetworkListViewProtocol?
    let interactor: AssetOperationNetworkListInteractorInputProtocol

    let viewModelFactory: AssetOperationNetworkListViewModelFactory

    let multichainToken: MultichainToken

    private(set) var resultModel: AssetOperationNetworkBuilderResult?

    init(
        interactor: AssetOperationNetworkListInteractorInputProtocol,
        multichainToken: MultichainToken,
        viewModelFactory: AssetOperationNetworkListViewModelFactory,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.multichainToken = multichainToken
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }

    func provideTitle() {
        fatalError("Must be overriden by subsclass")
    }

    func selectAsset(with _: ChainAssetId) {
        fatalError("Must be overriden by subsclass")
    }
}

// MARK: Private

private extension AssetOperationNetworkListPresenter {
    func provideViewModels() {
        guard let resultModel else { return }

        let viewModels = viewModelFactory.createViewModels(
            assets: resultModel.assets,
            priceData: resultModel.prices,
            locale: selectedLocale
        )

        view?.update(with: viewModels)
    }
}

// MARK: AssetOperationNetworkListPresenterProtocol

extension AssetOperationNetworkListPresenter: AssetOperationNetworkListPresenterProtocol {
    func setup() {
        provideTitle()

        interactor.setup()
    }
}

// MARK: AssetOperationNetworkListInteractorOutputProtocol

extension AssetOperationNetworkListPresenter: AssetOperationNetworkListInteractorOutputProtocol {
    func didReceive(result: AssetOperationNetworkBuilderResult) {
        resultModel = result

        provideViewModels()
    }
}

// MARK: Localizable

extension AssetOperationNetworkListPresenter: Localizable {
    func applyLocalization() {
        guard let view, view.isSetup else {
            return
        }

        provideTitle()
        provideViewModels()
    }
}
