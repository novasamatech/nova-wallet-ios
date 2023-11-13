import UIKit

final class TransactionHistoryWireframe: TransactionHistoryWireframeProtocol {
    let chainAsset: ChainAsset
    let assetListObservable: AssetListModelObservable
    let swapCompletionClosure: SwapCompletionClosure?

    init(
        chainAsset: ChainAsset,
        assetListObservable: AssetListModelObservable,
        swapCompletionClosure: SwapCompletionClosure?
    ) {
        self.chainAsset = chainAsset
        self.assetListObservable = assetListObservable
        self.swapCompletionClosure = swapCompletionClosure
    }

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
            assetListObservable: assetListObservable,
            swapCompletionClosure: swapCompletionClosure
        ) else {
            return
        }
        presentInNavigation(operationDetailsView.controller, from: view)
    }

    func closeTopModal(from view: TransactionHistoryViewProtocol) {
        view.controller.topModalViewController.dismiss(animated: true)
    }

    private func presentInNavigation(
        _ viewController: UIViewController,
        from view: TransactionHistoryViewProtocol
    ) {
        guard let navigationController = view.controller.navigationController else {
            return
        }

        let operationNavigationController = NovaNavigationController(rootViewController: viewController)

        navigationController.present(operationNavigationController, animated: true)
    }
}
