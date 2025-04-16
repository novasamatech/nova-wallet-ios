import Foundation
import BigInt
import Operation_iOS
import Foundation_iOS

final class ReceiveAssetOperationPresenter: AssetsSearchPresenter {
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
                receiveWireframe?.showSelectNetwork(
                    from: view,
                    multichainToken: multichainToken,
                    selectedAccount: selectedAccount
                )
            }
        )
    }

    private func processAssetSelected(_ chainAsset: ChainAsset) {
        let checkResult = TokenOperation.checkReceiveOperationAvailable(
            walletType: selectedAccount.type,
            chainAsset: chainAsset
        )

        handle(receiveCheckResult: checkResult, chainAsset: chainAsset)
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
}
