import Foundation
import UIKit
import UIKit_iOS
import Foundation_iOS

final class AssetDetailsWireframe {
    let operationState: AssetOperationState
    let swapState: SwapTokensFlowStateProtocol
    let ahmInfoSnapshot: AHMInfoService.Snapshot

    init(
        operationState: AssetOperationState,
        swapState: SwapTokensFlowStateProtocol,
        ahmInfoSnapshot: AHMInfoService.Snapshot
    ) {
        self.operationState = operationState
        self.swapState = swapState
        self.ahmInfoSnapshot = ahmInfoSnapshot
    }

    private func present(
        _ viewController: UIViewController,
        from view: AssetDetailsViewProtocol?
    ) {
        guard let navigationController = view?.controller.navigationController else {
            return
        }

        let factory = ModalSheetPresentationFactory(configuration: .nova)
        viewController.modalTransitioningFactory = factory
        viewController.modalPresentationStyle = .custom
        navigationController.present(viewController, animated: true)
    }
}

extension AssetDetailsWireframe: AssetDetailsWireframeProtocol {
    func showSendTokens(from view: AssetDetailsViewProtocol?, chainAsset: ChainAsset) {
        guard let transferSetupView = TransferSetupViewFactory.createView(
            from: chainAsset,
            recepient: nil
        ) else {
            return
        }

        let navigationController = NovaNavigationController(rootViewController: transferSetupView.controller)
        view?.controller.navigationController?.presentWithCardLayout(navigationController, animated: true)
    }

    func showReceiveTokens(
        from view: AssetDetailsViewProtocol?,
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
        view?.controller.navigationController?.presentWithCardLayout(navigationController, animated: true)
    }

    func showLocks(
        from view: AssetDetailsViewProtocol?,
        model: AssetDetailsLocksViewModel
    ) {
        let locksViewController = ModalInfoFactory.createFromBalanceContext(
            model.balanceContext,
            amountFormatter: model.amountFormatter,
            priceFormatter: model.priceFormatter,
            precision: model.precision
        )

        present(locksViewController, from: view)
    }

    func showNoSigning(from view: AssetDetailsViewProtocol?) {
        guard let confirmationView = MessageSheetViewFactory.createNoSigningView(with: {}) else {
            return
        }
        present(confirmationView.controller, from: view)
    }

    func showLedgerNotSupport(
        for tokenName: String,
        from view: AssetDetailsViewProtocol?
    ) {
        guard let confirmationView = LedgerMessageSheetViewFactory.createLedgerNotSupportTokenView(
            for: tokenName,
            cancelClosure: nil
        ) else {
            return
        }
        present(confirmationView.controller, from: view)
    }

    func showSwaps(
        from view: AssetDetailsViewProtocol?,
        chainAsset: ChainAsset
    ) {
        guard let swapsView = SwapSetupViewFactory.createView(
            state: swapState,
            payChainAsset: chainAsset,
            swapCompletionClosure: operationState.swapCompletionClosure
        ) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: swapsView.controller)

        view?.controller.presentWithCardLayout(navigationController, animated: true)
    }

    func showAssetDetails(
        from view: AssetDetailsViewProtocol?,
        chainAsset: ChainAsset
    ) {
        guard let assetDetailsView = AssetDetailsContainerViewFactory.createView(
            chainAsset: chainAsset,
            operationState: operationState,
            ahmInfoSnapshot: ahmInfoSnapshot
        ),
            let navigationController = view?.controller.navigationController
        else {
            return
        }

        var viewControllers = navigationController.viewControllers
        let index = viewControllers.count - 1
        viewControllers[index] = assetDetailsView.controller

        navigationController.setViewControllers(viewControllers, animated: true)
    }

    func presentSuccessAlert(
        from view: AssetDetailsViewProtocol?,
        message: String
    ) {
        let alertController = ModalAlertFactory.createMultilineSuccessAlert(message)
        view?.controller.present(alertController, animated: true)
    }

    func dropModalFlow(
        from view: AssetDetailsViewProtocol?,
        completion: @escaping () -> Void
    ) {
        view?.controller.presentedViewController?.dismiss(
            animated: true,
            completion: completion
        )
    }
}
