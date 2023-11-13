import Foundation
import SoraFoundation
import SoraUI

final class SwapSetupWireframe: SwapSetupWireframeProtocol {
    let assetListObservable: AssetListModelObservable
    let state: GeneralStorageSubscriptionFactoryProtocol

    init(assetListObservable: AssetListModelObservable, state: GeneralStorageSubscriptionFactoryProtocol) {
        self.assetListObservable = assetListObservable
        self.state = state
    }

    func showPayTokenSelection(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset?,
        completionHandler: @escaping (ChainAsset) -> Void
    ) {
        guard let selectTokenView = SwapAssetsOperationViewFactory.createSelectPayTokenView(
            for: assetListObservable,
            chainAsset: chainAsset,
            selectClosure: completionHandler
        ) else {
            return
        }

        let navigationController = NovaNavigationController(
            rootViewController: selectTokenView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showReceiveTokenSelection(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset?,
        completionHandler: @escaping (ChainAsset) -> Void
    ) {
        guard let selectTokenView = SwapAssetsOperationViewFactory.createSelectReceiveTokenView(
            for: assetListObservable,
            chainAsset: chainAsset,
            selectClosure: completionHandler
        ) else {
            return
        }

        let navigationController = NovaNavigationController(
            rootViewController: selectTokenView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showSettings(
        from view: ControllerBackedProtocol?,
        percent: BigRational?,
        chainAsset: ChainAsset,
        completionHandler: @escaping (BigRational) -> Void
    ) {
        guard let settingsView = SwapSlippageViewFactory.createView(
            percent: percent,
            chainAsset: chainAsset,
            completionHandler: completionHandler
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            settingsView.controller,
            animated: true
        )
    }

    func showConfirmation(
        from view: ControllerBackedProtocol?,
        initState: SwapConfirmInitState
    ) {
        guard let confimView = SwapConfirmViewFactory.createView(
            initState: initState,
            generalSubscriptonFactory: state
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            confimView.controller,
            animated: true
        )
    }

    func showNetworkFeeAssetSelection(
        form view: ControllerBackedProtocol?,
        viewModel: SwapNetworkFeeSheetViewModel
    ) {
        let bottomSheet = SwapNetworkFeeSheetViewFactory.createView(from: viewModel)

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)

        bottomSheet.controller.modalTransitioningFactory = factory
        bottomSheet.controller.modalPresentationStyle = .custom

        view?.controller.present(bottomSheet.controller, animated: true)
    }

    func showGetTokenOptions(
        form view: ControllerBackedProtocol?,
        purchaseHadler: PurchaseFlowManaging,
        destinationChainAsset: ChainAsset,
        locale: Locale
    ) {
        let completion: GetTokenOptionsCompletion = { [weak self, weak purchaseHadler] result in
            guard let self = self else {
                return
            }

            switch result {
            case let .crosschains(origins, xcmTransfers):
                self.showGetTokensByCrosschain(
                    from: view,
                    origins: origins,
                    destination: destinationChainAsset,
                    xcmTransfers: xcmTransfers
                )
            case let .receive(account):
                self.showGetTokensByReceive(
                    from: view,
                    chainAsset: destinationChainAsset,
                    metaChainAccountResponse: account
                )
            case let .buy(actions):
                purchaseHadler?.startPuchaseFlow(
                    from: view,
                    purchaseActions: actions,
                    wireframe: self,
                    locale: locale
                )
            }
        }

        guard let bottomSheet = GetTokenOptionsViewFactory.createView(
            from: destinationChainAsset,
            assetModelObservable: assetListObservable,
            completion: completion
        ) else {
            return
        }

        view?.controller.present(bottomSheet.controller, animated: true)
    }

    func showGetTokensByCrosschain(
        from view: ControllerBackedProtocol?,
        origins: [ChainAsset],
        destination: ChainAsset,
        xcmTransfers: XcmTransfers
    ) {
        guard let transferView = TransferSetupViewFactory.createCrosschainView(
            from: origins,
            to: destination,
            xcmTransfers: xcmTransfers,
            assetListObservable: assetListObservable,
            transferCompletion: nil
        ) else {
            return
        }

        let navigationController = NovaNavigationController(rootViewController: transferView.controller)

        view?.controller.present(navigationController, animated: true)
    }

    func showGetTokensByReceive(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        metaChainAccountResponse: MetaChainAccountResponse
    ) {
        guard let receiveTokensView = AssetReceiveViewFactory.createView(
            chainAsset: chainAsset,
            metaChainAccountResponse: metaChainAccountResponse
        ) else {
            return
        }

        let navigationController = NovaNavigationController(rootViewController: receiveTokensView.controller)

        view?.controller.present(navigationController, animated: true)
    }
}
