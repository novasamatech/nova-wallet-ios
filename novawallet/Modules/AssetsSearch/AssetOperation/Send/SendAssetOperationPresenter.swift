import Foundation
import BigInt
import RobinHood
import SoraFoundation

final class SendAssetOperationPresenter: AssetsSearchPresenter {
    var sendAssetWireframe: SendAssetOperationWireframeProtocol? {
        wireframe as? SendAssetOperationWireframeProtocol
    }

    init(
        initState: AssetListInitState,
        interactor: AssetsSearchInteractorInputProtocol,
        viewModelFactory: AssetListAssetViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        wireframe: SendAssetOperationWireframeProtocol
    ) {
        super.init(
            initState: initState,
            delegate: nil,
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager
        )

        chainAssetsFilter = { chainAsset in
            let assetMapper = CustomAssetMapper(
                type: chainAsset.asset.type,
                typeExtras: chainAsset.asset.typeExtras
            )
            guard let transfersEnabled = try? assetMapper.transfersEnabled() else {
                return false
            }
            return transfersEnabled
        }
    }

    override func selectAsset(for chainAssetId: ChainAssetId) {
        guard let chainAsset = chainAsset(for: chainAssetId) else {
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
