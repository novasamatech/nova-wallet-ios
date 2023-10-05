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

    let selectClosure: (ChainAsset) -> Void

    init(
        selectClosure: @escaping (ChainAsset) -> Void,
        interactor: SwapAssetsOperationInteractorInputProtocol,
        viewModelFactory: AssetListAssetViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        wireframe: SwapAssetsOperationWireframeProtocol
    ) {
        self.selectClosure = selectClosure

        super.init(
            delegate: nil,
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

    override func selectAsset(for chainAssetId: ChainAssetId) {
        guard let chainAsset = result?.state.chainAsset(for: chainAssetId) else {
            return
        }
        selectClosure(chainAsset)
        wireframe.close(view: view)
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
