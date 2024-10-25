import Foundation
import BigInt
import Operation_iOS
import SoraFoundation

final class ReceiveAssetOperationPresenter: AssetOperationPresenter {
    var receiveWireframe: ReceiveAssetOperationWireframeProtocol? {
        wireframe as? ReceiveAssetOperationWireframeProtocol
    }

    let selectedAccount: MetaAccountModel

    init(
        interactor: AssetsSearchInteractorInputProtocol,
        viewModelFactory: AssetListAssetViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        selectedAccount: MetaAccountModel,
        wireframe: ReceiveAssetOperationWireframeProtocol
    ) {
        self.selectedAccount = selectedAccount
        super.init(
            delegate: nil,
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager
        )
    }

    private func handle(receiveCheckResult: ReceiveAvailableCheckResult, chainAsset: ChainAsset) {
        switch receiveCheckResult {
        case let .common(checkResult):
            receiveWireframe?.presentOperationCompletion(on: view, by: checkResult, successRouteClosure: {
                if let metaChainAccountResponse = selectedAccount.fetchMetaChainAccount(
                    for: chainAsset.chain.accountRequest()) {
                    receiveWireframe?.showReceiveTokens(
                        from: view,
                        chainAsset: chainAsset,
                        metaChainAccountResponse: metaChainAccountResponse
                    )
                }
            })
        }
    }

    override func selectAsset(for chainAssetId: ChainAssetId) {
        guard let chainAsset = result?.state.chainAsset(for: chainAssetId) else {
            return
        }

        let checkResult = TokenOperation.checkReceiveOperationAvailable(
            walletType: selectedAccount.type,
            chainAsset: chainAsset
        )

        handle(receiveCheckResult: checkResult, chainAsset: chainAsset)
    }
}
