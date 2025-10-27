import Foundation
import Foundation_iOS

final class GiftOperationNetworkListPresenter: AssetOperationNetworkListPresenter {
    let wireframe: GiftAssetOperationWireframeProtocol

    init(
        interactor: AssetOperationNetworkListInteractorInputProtocol,
        wireframe: GiftAssetOperationWireframeProtocol,
        multichainToken: MultichainToken,
        viewModelFactory: AssetOperationNetworkListViewModelFactory,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.wireframe = wireframe

        super.init(
            interactor: interactor,
            multichainToken: multichainToken,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager
        )
    }

    override func provideTitle() {
        let title = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.giftOperationNetworkListTitle(multichainToken.symbol)

        view?.updateHeader(with: title)
    }

    override func selectAsset(with chainAssetId: ChainAssetId) {
        guard let chainAsset = resultModel?.state.chainAsset(for: chainAssetId) else {
            return
        }

        wireframe.showGiftTokens(from: view, chainAsset: chainAsset)
    }
}
