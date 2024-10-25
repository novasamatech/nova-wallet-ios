import Foundation
import BigInt
import Operation_iOS
import SoraFoundation

final class SendAssetOperationPresenter: AssetOperationPresenter {
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

    override func selectGroup(with symbol: AssetModel.Symbol) {
        processWithCheck(
            symbol,
            onSingleInstance: { chainAsset in
                sendAssetWireframe?.showSendTokens(
                    from: view,
                    chainAsset: chainAsset
                )
            },
            onMultipleInstances: { multichainToken in
                sendAssetWireframe?.showSelectNetwork(
                    from: view,
                    multichainToken: multichainToken
                )
            }
        )
    }
}

extension SendAssetOperationPresenter: SendAssetOperationPresenterProtocol {
    func buy() {
        sendAssetWireframe?.showBuyTokens(from: view)
    }
}
