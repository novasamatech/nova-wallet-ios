import Foundation
import BigInt
import RobinHood
import SoraFoundation

final class ReceiveAssetOperationPresenter: AssetsSearchPresenter {
    var receiveWireframe: ReceiveAssetOperationWireframeProtocol? {
        wireframe as? ReceiveAssetOperationWireframeProtocol
    }

    let selectedAccount: MetaAccountModel

    init(
        initState: AssetListInitState,
        interactor: AssetsSearchInteractorInputProtocol,
        viewModelFactory: AssetListAssetViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        selectedAccount: MetaAccountModel,
        wireframe: ReceiveAssetOperationWireframeProtocol
    ) {
        self.selectedAccount = selectedAccount
        super.init(
            initState: initState,
            delegate: nil,
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager
        )
        chainAssetsFilter = nil
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
        guard let chainAsset = chainAsset(for: chainAssetId) else {
            return
        }

        let checkResult = TokenOperation.checkReceiveOperationAvailable(
            walletType: selectedAccount.type,
            chainAsset: chainAsset
        )

        handle(receiveCheckResult: checkResult, chainAsset: chainAsset)
    }
}
