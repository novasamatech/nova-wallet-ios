import UIKit
import UIKit_iOS
import Foundation_iOS

enum GetTokenOptionsViewFactory {
    static func createView(
        from destinationChainAsset: ChainAsset,
        assetModelObservable: AssetListModelObservable,
        completion: @escaping GetTokenOptionsCompletion
    ) -> GetTokenOptionsViewProtocol? {
        guard let interactor = createInteractor(
            from: destinationChainAsset,
            assetModelObservable: assetModelObservable
        ) else {
            return nil
        }

        let wireframe = GetTokenOptionsWireframe(completion: completion)

        let presenter = GetTokenOptionsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            destinationChainAsset: destinationChainAsset
        )

        let view = GetTokenOptionsViewController(operationPresenter: presenter)

        view.localizedTitle = .init {
            R.string.localizable.swapsSetupDepositTitle(
                destinationChainAsset.asset.symbol,
                preferredLanguages: $0.rLanguages
            )
        }

        view.selectedIndex = NSNotFound
        view.modalPresentationStyle = .custom
        view.headerBorderType = .none
        view.separatorStyle = .none
        view.separatorColor = R.color.colorDivider()
        view.cellHeight = 48

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)
        view.modalTransitioningFactory = factory

        let height = view.headerHeight + CGFloat(presenter.allOperations.count) * view.cellHeight + view.footerHeight
        view.preferredContentSize = CGSize(width: 0.0, height: height)

        view.localizationManager = LocalizationManager.shared

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        from destinationChainAsset: ChainAsset,
        assetModelObservable: AssetListModelObservable
    ) -> GetTokenOptionsInteractor? {
        guard let selectedWallet = SelectedWalletSettings.shared.value else {
            return nil
        }

        let xcmTransfersSyncService = XcmTransfersSyncService(
            remoteUrl: ApplicationConfig.shared.xcmTransfersURL,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        return GetTokenOptionsInteractor(
            selectedWallet: selectedWallet,
            destinationChainAsset: destinationChainAsset,
            assetModelObservable: assetModelObservable,
            xcmTransfersSyncService: xcmTransfersSyncService,
            purchaseProvider: PurchaseAggregator.defaultAggregator(),
            logger: Logger.shared
        )
    }
}
