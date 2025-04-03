import Foundation
import Foundation_iOS

final class ReceiveOperationNetworkListPresenter: AssetOperationNetworkListPresenter {
    let wireframe: ReceiveAssetOperationWireframeProtocol

    let selectedAccount: MetaAccountModel

    init(
        interactor: AssetOperationNetworkListInteractorInputProtocol,
        wireframe: ReceiveAssetOperationWireframeProtocol,
        multichainToken: MultichainToken,
        viewModelFactory: AssetOperationNetworkListViewModelFactory,
        selectedAccount: MetaAccountModel,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.selectedAccount = selectedAccount
        self.wireframe = wireframe

        super.init(
            interactor: interactor,
            multichainToken: multichainToken,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager
        )
    }

    override func provideTitle() {
        let title = R.string.localizable.receiveOperationNetworkListTitle(
            multichainToken.symbol,
            preferredLanguages: selectedLocale.rLanguages
        )

        view?.updateHeader(with: title)
    }

    private func handle(receiveCheckResult: ReceiveAvailableCheckResult, chainAsset: ChainAsset) {
        switch receiveCheckResult {
        case let .common(checkResult):
            wireframe.presentOperationCompletion(on: view, by: checkResult, successRouteClosure: {
                if let metaChainAccountResponse = selectedAccount.fetchMetaChainAccount(
                    for: chainAsset.chain.accountRequest()) {
                    wireframe.showReceiveTokens(
                        from: view,
                        chainAsset: chainAsset,
                        metaChainAccountResponse: metaChainAccountResponse
                    )
                }
            })
        }
    }

    override func selectAsset(with chainAssetId: ChainAssetId) {
        guard let chainAsset = resultModel?.state.chainAsset(for: chainAssetId) else {
            return
        }

        let checkResult = TokenOperation.checkReceiveOperationAvailable(
            walletType: selectedAccount.type,
            chainAsset: chainAsset
        )

        handle(receiveCheckResult: checkResult, chainAsset: chainAsset)
    }
}
