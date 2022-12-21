import Foundation
import UIKit
import SoraUI
import SoraFoundation

final class AssetDetailsWireframe: AssetDetailsWireframeProtocol {
    func showPurchaseTokens(
        from view: AssetDetailsViewProtocol?,
        action: PurchaseAction,
        delegate: PurchaseDelegate
    ) {
        guard let purchaseView = PurchaseViewFactory.createView(
            for: action,
            delegate: delegate
        ) else {
            return
        }
        present(purchaseView.controller, from: view)
    }

    func showSendTokens(from view: AssetDetailsViewProtocol?, chainAsset: ChainAsset) {
        guard let transferSetupView = TransferSetupViewFactory.createView(
            from: chainAsset,
            recepient: nil
        ) else {
            return
        }
        guard let navigationController = view?.controller.navigationController else {
            return
        }
        let fearlessNavigationController = FearlessNavigationController(
            rootViewController: transferSetupView.controller)
        navigationController.present(fearlessNavigationController, animated: true)
    }

    func showReceiveTokens(
        from view: AssetDetailsViewProtocol?,
        chainAsset: ChainAsset,
        metaChainAccountResponse: MetaChainAccountResponse
    ) {
        guard let receiveTokensView = NewReceiveViewFactory.createView(
            chainAsset: chainAsset,
            metaChainAccountResponse: metaChainAccountResponse
        ) else {
            return
        }
        guard let navigationController = view?.controller.navigationController else {
            return
        }
        let fearlessNavigationController = FearlessNavigationController(
            rootViewController: receiveTokensView.controller)
        navigationController.present(fearlessNavigationController, animated: true)
    }

    func showPurchaseProviders(
        from view: AssetDetailsViewProtocol?,
        actions: [PurchaseAction],
        delegate: ModalPickerViewControllerDelegate
    ) {
        guard let pickerView = ModalPickerFactory.createPickerForList(
            actions,
            delegate: delegate,
            context: nil
        ) else {
            return
        }
        guard let navigationController = view?.controller.navigationController else {
            return
        }
        navigationController.present(pickerView, animated: true)
    }

    func showLocks(from view: AssetDetailsViewProtocol?, model: AssetDetailsLocksViewModel) {
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

    func showLedgerNotSupport(for tokenName: String, from view: AssetDetailsViewProtocol?) {
        guard let confirmationView = LedgerMessageSheetViewFactory.createLedgerNotSupportTokenView(
            for: tokenName,
            cancelClosure: nil
        ) else {
            return
        }
        present(confirmationView.controller, from: view)
    }

    private func present(_ viewController: UIViewController, from view: AssetDetailsViewProtocol?) {
        guard let navigationController = view?.controller.navigationController else {
            return
        }
        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.fearless)
        viewController.modalTransitioningFactory = factory
        viewController.modalPresentationStyle = .custom
        navigationController.present(viewController, animated: true)
    }

    func presentSuccessAlert(from view: AssetDetailsViewProtocol?, message: String) {
        let alertController = ModalAlertFactory.createMultilineSuccessAlert(message)
        view?.controller.present(alertController, animated: true)
    }
}
