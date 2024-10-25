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
        guard let multichainToken = result?.assetGroups.first(
            where: { $0.multichainToken.symbol == symbol }
        )?.multichainToken else {
            return
        }

        if multichainToken.instances.count > 1 {
            sendAssetWireframe?.showSelectNetwork(
                from: view,
                multichainToken: multichainToken
            )
        } else if
            let chainAssetId = multichainToken.instances.first?.chainAssetId,
            let chainAsset = result?.state.chainAsset(for: chainAssetId) {
            sendAssetWireframe?.showSendTokens(
                from: view,
                chainAsset: chainAsset
            )
        }
    }
}

extension SendAssetOperationPresenter: SendAssetOperationPresenterProtocol {
    func buy() {
        sendAssetWireframe?.showBuyTokens(from: view)
    }
}
