import Foundation
import SoraFoundation

class AssetOperationNetworkListPresenter {
    weak var view: AssetOperationNetworkListViewProtocol?
    let wireframe: AssetOperationNetworkListWireframeProtocol
    let interactor: AssetOperationNetworkListInteractorInputProtocol

    let viewModelFactory: AssetOperationNetworkListViewModelFactory

    let multichainToken: MultichainToken

    private var resultModel: AssetOperationNetworkBuilderResult?

    init(
        interactor: AssetOperationNetworkListInteractorInputProtocol,
        wireframe: AssetOperationNetworkListWireframeProtocol,
        multichainToken: MultichainToken,
        viewModelFactory: AssetOperationNetworkListViewModelFactory
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.multichainToken = multichainToken
        self.viewModelFactory = viewModelFactory
    }

    func provideTitle() {
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

// MARK: AssetOperationNetworkSelectionPresenterProtocol

extension AssetOperationNetworkListPresenter: AssetOperationNetworkListPresenterProtocol {
    func setup() {
        provideTitle()

        interactor.setup()
    }

    func selectAsset(with chainAssetId: ChainAssetId) {
        guard let chainAsset = resultModel?.assets.first(
            where: { $0.chainAssetModel.chainAssetId == chainAssetId }
        )?.chainAssetModel else {
            return
        }

        wireframe.showOperation(for: chainAsset)
    }
}

// MARK: AssetOperationNetworkSelectionInteractorOutputProtocol

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
