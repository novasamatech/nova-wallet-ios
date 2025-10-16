import Foundation
import Foundation_iOS

final class SwapOperationNetworkListPresenter: AssetOperationNetworkListPresenter {
    let wireframe: SwapAssetsOperationWireframeProtocol

    let selectClosure: (ChainAsset) -> Void
    let selectClosureStrategy: SubmoduleNavigationStrategy

    init(
        interactor: AssetOperationNetworkListInteractorInputProtocol,
        wireframe: SwapAssetsOperationWireframeProtocol,
        multichainToken: MultichainToken,
        viewModelFactory: AssetOperationNetworkListViewModelFactory,
        selectClosure: @escaping (ChainAsset) -> Void,
        selectClosureStrategy: SubmoduleNavigationStrategy,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.wireframe = wireframe
        self.selectClosure = selectClosure
        self.selectClosureStrategy = selectClosureStrategy

        super.init(
            interactor: interactor,
            multichainToken: multichainToken,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager
        )
    }

    override func provideTitle() {
        let title = R.string(preferredLanguages: selectedLocale.rLanguages
        ).localizable.swapOperationNetworkListTitle(multichainToken.symbol)

        view?.updateHeader(with: title)
    }

    override func selectAsset(with chainAssetId: ChainAssetId) {
        guard let chainAsset = resultModel?.state.chainAsset(for: chainAssetId) else {
            return
        }

        selectClosureStrategy.applyStrategy(
            for: { dismissalCallback in
                self.wireframe.close(view: self.view, completion: dismissalCallback)
            },
            callback: { [weak self] in
                self?.selectClosure(chainAsset)
            }
        )
    }
}
