import Foundation
import BigInt
import Operation_iOS
import Foundation_iOS

final class GiftAssetOperationPresenter: AssetsSearchPresenter {
    var giftAssetWireframe: GiftAssetOperationWireframeProtocol? {
        wireframe as? GiftAssetOperationWireframeProtocol
    }

    init(
        interactor: AssetsSearchInteractorInputProtocol,
        viewModelFactory: AssetListAssetViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        wireframe: GiftAssetOperationWireframeProtocol
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

        processAssetSelected(chainAsset)
    }

    override func selectGroup(with symbol: AssetModel.Symbol) {
        processGroupSelectionWithCheck(
            symbol,
            onSingleInstance: { chainAsset in
                processAssetSelected(chainAsset)
            },
            onMultipleInstances: { multichainToken in
                giftAssetWireframe?.showSelectNetwork(
                    from: view,
                    multichainToken: multichainToken
                )
            }
        )
    }

    private func processAssetSelected(_ chainAsset: ChainAsset) {
        if TokenOperation.checkTransferOperationAvailable() {
            giftAssetWireframe?.showGiftTokens(
                from: view,
                chainAsset: chainAsset
            )
        }
    }
}
