import UIKit
import UIKit_iOS
import Foundation_iOS

enum GetTokenOptionsViewFactory {
    static func createView(
        from destinationChainAsset: ChainAsset,
        assetModelObservable: AssetListModelObservable,
        offersSwap: Bool,
        completion: @escaping GetTokenOptionsCompletion
    ) -> GetTokenOptionsViewProtocol? {
        guard let interactor = createInteractor(
            from: destinationChainAsset,
            assetModelObservable: assetModelObservable,
            offersSwap: offersSwap
        ) else {
            return nil
        }

        let wireframe = GetTokenOptionsWireframe(completion: completion)

        let presenter = GetTokenOptionsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            destinationChainAsset: destinationChainAsset,
            allOperations: interactor.allOperations
        )

        let view = GetTokenOptionsViewController(operationPresenter: presenter)

        view.localizedTitle = .init {
            R.string(
                preferredLanguages: $0.rLanguages
            ).localizable.swapsSetupDepositTitle(destinationChainAsset.asset.symbol)
        }

        view.selectedIndex = NSNotFound
        view.modalPresentationStyle = .custom
        view.headerBorderType = .none
        view.separatorStyle = .none
        view.separatorColor = R.color.colorDivider()
        view.cellHeight = 48

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.novaManual)
        view.modalTransitioningFactory = factory

        view.updatePreferredHeight(rowsCount: presenter.operations.count)

        view.localizationManager = LocalizationManager.shared

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        from destinationChainAsset: ChainAsset,
        assetModelObservable: AssetListModelObservable,
        offersSwap: Bool
    ) -> GetTokenOptionsInteractor? {
        guard let selectedWallet = SelectedWalletSettings.shared.value else {
            return nil
        }

        let xcmTransfersSyncService = XcmTransfersSyncService(
            config: ApplicationConfig.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let featureChecker = FeatureSupportChecker(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            userStorageFacade: UserDataStorageFacade.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let swapState: SwapTokensFlowStateProtocol? = offersSwap ? SwapTokensFlowState(
            assetListObservable: assetModelObservable,
            assetExchangeParams: AssetExchangeGraphProvidingParams(wallet: selectedWallet)
        ) : nil

        return GetTokenOptionsInteractor(
            selectedWallet: selectedWallet,
            destinationChainAsset: destinationChainAsset,
            assetModelObservable: assetModelObservable,
            xcmTransfersSyncService: xcmTransfersSyncService,
            featureChecker: featureChecker,
            rampProvider: RampAggregator.defaultAggregator(),
            globalConfigProvider: GlobalConfigProvider.shared,
            swapState: swapState,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )
    }
}
