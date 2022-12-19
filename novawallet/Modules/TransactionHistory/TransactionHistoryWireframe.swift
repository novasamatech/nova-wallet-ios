import Foundation
import CommonWallet

final class TransactionHistoryWireframe: TransactionHistoryWireframeProtocol {
    let chainAsset: ChainAsset

    init(chainAsset: ChainAsset) {
        self.chainAsset = chainAsset
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

        guard let navigationController = view.controller.navigationController else {
            return
        }

        navigationController.present(filterView.controller, animated: true)
    }

    func showOperationDetails(
        from view: TransactionHistoryViewProtocol,
        operation: TransactionHistoryItem
    ) {
        guard let operationDetailsView = OperationDetailsViewFactory.createView(for: operation, chainAsset: chainAsset) else {
            return
        }

        guard let navigationController = view.controller.navigationController else {
            return
        }

        navigationController.present(operationDetailsView.controller, animated: true)
    }

    func closeTopModal(from view: TransactionHistoryViewProtocol) {
        view.controller.topModalViewController.dismiss(animated: true)
    }
}
