import Foundation

class SendOperationNetworkListPresenter: AssetOperationNetworkListPresenter {
    let wireframe: SendAssetOperationWireframeProtocol

    init(
        interactor: AssetOperationNetworkListInteractorInputProtocol,
        wireframe: SendAssetOperationWireframeProtocol,
        multichainToken: MultichainToken,
        viewModelFactory: AssetOperationNetworkListViewModelFactory
    ) {
        self.wireframe = wireframe

        super.init(
            interactor: interactor,
            multichainToken: multichainToken,
            viewModelFactory: viewModelFactory
        )
    }

    override func provideTitle() {
        let title = R.string.localizable.sendOperationNetworkListTitle(
            multichainToken.symbol,
            preferredLanguages: selectedLocale.rLanguages
        )

        view?.updateHeader(with: title)
    }

    override func selectAsset(with chainAssetId: ChainAssetId) {
        guard let chainAsset = resultModel?.state.chainAsset(for: chainAssetId) else {
            return
        }

        wireframe.showSendTokens(from: view, chainAsset: chainAsset)
    }
}