import Foundation
import BigInt
import RobinHood
import SoraFoundation

final class SendAssetOperationPresenter: AssetsSearchPresenter {
    var sendAssetWireframe: SendAssetOperationWireframeProtocol? {
        wireframe as? SendAssetOperationWireframeProtocol
    }

    init(
        interactor: AssetsSearchInteractorInputProtocol,
        viewModelFactory: AssetListAssetViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        wireframe: SendAssetOperationWireframeProtocol
    ) {
        super.init(
            delegate: nil,
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager
        )
    }

    override func selectAsset(for chainAssetId: ChainAssetId) {
        guard let chainAsset = result?.state.chainAsset(for: chainAssetId) else {
            return
        }

        if TokenOperation.checkTransferOperationAvailable() {
            sendAssetWireframe?.showSendTokens(
                from: view,
                chainAsset: chainAsset
            )
        }
    }
}
