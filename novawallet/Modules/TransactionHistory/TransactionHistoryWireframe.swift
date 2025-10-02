import UIKit

final class TransactionHistoryWireframe {
    let chainAsset: ChainAsset
    let operationState: AssetOperationState
    let swapState: SwapTokensFlowStateProtocol

    init(
        chainAsset: ChainAsset,
        operationState: AssetOperationState,
        swapState: SwapTokensFlowStateProtocol
    ) {
        self.chainAsset = chainAsset
        self.operationState = operationState
        self.swapState = swapState
    }
}

// MARK: - Private

private extension TransactionHistoryWireframe {
    func presentInNavigation(
        _ viewController: UIViewController,
        from view: TransactionHistoryViewProtocol
    ) {
        guard let navigationController = view.controller.navigationController else {
            return
        }

        let operationNavigationController = NovaNavigationController(rootViewController: viewController)

        navigationController.presentWithCardLayout(operationNavigationController, animated: true)
    }
}

// MARK: - TransactionHistoryWireframeProtocol

extension TransactionHistoryWireframe: TransactionHistoryWireframeProtocol {
    func showFilter(
        from view: TransactionHistoryViewProtocol,
        filter: WalletHistoryFilter,
        delegate: TransactionHistoryFilterEditingDelegate?
    ) {
        guard let filterView = WalletHistoryFilterViewFactory.createView(
            filter: filter,
            delegate: delegate
        ) else {
            return
        }

        presentInNavigation(filterView.controller, from: view)
    }

    func showOperationDetails(
        from view: TransactionHistoryViewProtocol,
        operation: TransactionHistoryItem
    ) {
        guard let operationDetailsView = OperationDetailsViewFactory.createView(
            for: operation,
            chainAsset: chainAsset,
            operationState: operationState,
            swapState: swapState
        ) else {
            return
        }
        presentInNavigation(operationDetailsView.controller, from: view)
    }

    func showAssetDetails(
        from view: TransactionHistoryViewProtocol?,
        chainAsset: ChainAsset
    ) {
        guard let assetDetailsView = AssetDetailsContainerViewFactory.createView(
            chainAsset: chainAsset,
            operationState: operationState
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

    func closeTopModal(from view: TransactionHistoryViewProtocol) {
        view.controller.topModalViewController.dismiss(animated: true)
    }
}
