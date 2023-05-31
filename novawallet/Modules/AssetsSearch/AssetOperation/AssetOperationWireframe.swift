import UIKit
import SoraUI

final class AssetOperationWireframe: AssetOperationWireframeProtocol {
    func showSendTokens(from view: AssetOperationViewProtocol?, chainAsset: ChainAsset) {
        guard let transferSetupView = TransferSetupViewFactory.createView(
            from: chainAsset,
            recepient: nil
        ) else {
            return
        }
        view?.controller.navigationController?.pushViewController(transferSetupView.controller, animated: true)
    }

    func showReceiveTokens(
        from view: AssetOperationViewProtocol?,
        chainAsset: ChainAsset,
        metaChainAccountResponse: MetaChainAccountResponse
    ) {
        guard let receiveTokensView = AssetReceiveViewFactory.createView(
            chainAsset: chainAsset,
            metaChainAccountResponse: metaChainAccountResponse
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(receiveTokensView.controller, animated: true)
    }

    func showNoLedgerSupport(from view: AssetOperationViewProtocol?, tokenName: String) {
        guard let confirmationView = LedgerMessageSheetViewFactory.createLedgerNotSupportTokenView(
            for: tokenName,
            cancelClosure: nil
        ) else {
            return
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)

        confirmationView.controller.modalTransitioningFactory = factory
        confirmationView.controller.modalPresentationStyle = .custom

        view?.controller.present(confirmationView.controller, animated: true)
    }

    func showNoKeys(from view: AssetOperationViewProtocol?) {
        guard let confirmationView = MessageSheetViewFactory.createNoSigningView(with: {}) else {
            return
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)

        confirmationView.controller.modalTransitioningFactory = factory
        confirmationView.controller.modalPresentationStyle = .custom

        view?.controller.present(confirmationView.controller, animated: true)
    }

    func showPurchaseProviders(
        from view: AssetOperationViewProtocol?,
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

    func showPurchaseTokens(
        from view: AssetOperationViewProtocol?,
        action: PurchaseAction,
        delegate: PurchaseDelegate
    ) {
        guard let purchaseView = PurchaseViewFactory.createView(
            for: action,
            delegate: delegate
        ) else {
            return
        }
        purchaseView.controller.modalPresentationStyle = .fullScreen
        view?.controller.present(purchaseView.controller, animated: true)
    }

    func presentSuccessAlert(from view: AssetOperationViewProtocol?, message: String) {
        let alertController = ModalAlertFactory.createMultilineSuccessAlert(message)
        view?.controller.present(alertController, animated: true)
    }
}

extension AssetOperationWireframe: AssetsSearchWireframeProtocol {
    func close(view: AssetsSearchViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true)
    }
}
