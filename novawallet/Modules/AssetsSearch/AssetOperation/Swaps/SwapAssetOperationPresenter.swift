import Foundation
import BigInt
import Operation_iOS
import SoraFoundation

final class SwapAssetsOperationPresenter: AssetOperationPresenter {
    var swapAssetsWireframe: SwapAssetsOperationWireframeProtocol? {
        wireframe as? SwapAssetsOperationWireframeProtocol
    }

    var swapAssetsView: SwapAssetsViewProtocol? {
        view as? SwapAssetsViewProtocol
    }

    let selectClosure: (ChainAsset) -> Void

    let selectClosureStrategy: SubmoduleNavigationStrategy

    let logger: LoggerProtocol

    init(
        selectClosure: @escaping (ChainAsset) -> Void,
        selectClosureStrategy: SubmoduleNavigationStrategy,
        interactor: SwapAssetsOperationInteractorInputProtocol,
        viewModelFactory: AssetListAssetViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        wireframe: SwapAssetsOperationWireframeProtocol,
        logger: Logger
    ) {
        self.selectClosure = selectClosure
        self.selectClosureStrategy = selectClosureStrategy
        self.logger = logger

        super.init(
            delegate: nil,
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager
        )
    }

    override func setup() {
        interactor.setup()
        swapAssetsView?.didStartLoading()
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
                swapAssetsWireframe?.showSelectNetwork(
                    from: view,
                    multichainToken: multichainToken,
                    selectClosure: selectClosure,
                    selectClosureStrategy: selectClosureStrategy
                )
            }
        )
    }

    private func processAssetSelected(_ chainAsset: ChainAsset) {
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

extension SwapAssetsOperationPresenter: SwapAssetsOperationPresenterProtocol {
    func directionsLoaded() {
        swapAssetsView?.didStopLoading()
    }

    func didReceive(error: SwapAssetsOperationError) {
        logger.error("Did receive error: \(error)")

        swapAssetsWireframe?.presentRequestStatus(
            on: swapAssetsView,
            locale: selectedLocale,
            retryAction: { [weak self] in
                self?.interactor.setup()
            }
        )
    }
}
