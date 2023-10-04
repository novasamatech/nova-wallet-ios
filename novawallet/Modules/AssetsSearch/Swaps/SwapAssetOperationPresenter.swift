import Foundation
import BigInt
import RobinHood
import SoraFoundation

final class SwapAssetsOperationPresenter: AssetsSearchPresenter {
    var swapAssetsWireframe: SwapAssetsOperationWireframeProtocol? {
        wireframe as? SwapAssetsOperationWireframeProtocol
    }

    var swapAssetsView: SwapAssetsViewProtocol? {
        view as? SwapAssetsViewProtocol
    }

    init(
        delegate: AssetsSearchDelegate,
        interactor: SwapAssetsOperationInteractorInputProtocol,
        viewModelFactory: AssetListAssetViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        wireframe: SwapAssetsOperationWireframeProtocol
    ) {
        super.init(
            delegate: delegate,
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager
        )
    }

    override func setup() {
        interactor.setup()
        swapAssetsView?.didStartLoading()
    }
}

extension SwapAssetsOperationPresenter: SwapAssetsOperationPresenterProtocol {
    func directionsLoaded() {
        swapAssetsView?.didStopLoading()
    }

    func didReceive(error _: SwapAssetsOperationError) {
        swapAssetsWireframe?.presentRequestStatus(
            on: swapAssetsView,
            locale: selectedLocale,
            retryAction: { [weak self] in
                self?.interactor.setup()
            }
        )
    }
}
