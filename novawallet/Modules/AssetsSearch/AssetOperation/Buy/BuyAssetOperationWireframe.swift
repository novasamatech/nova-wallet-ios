import UIKit
import SoraUI

protocol BuyAssetOperationWireframeProtocol: AssetsSearchWireframeProtocol, MessageSheetPresentable {
    func showPurchaseProviders(
        from view: ControllerBackedProtocol?,
        actions: [PurchaseAction],
        delegate: ModalPickerViewControllerDelegate
    )
    func showPurchaseTokens(
        from view: ControllerBackedProtocol?,
        action: PurchaseAction,
        delegate: PurchaseDelegate
    )
    func presentSuccessAlert(from view: ControllerBackedProtocol?, message: String)
}

final class BuyAssetOperationWireframe: BuyAssetOperationWireframeProtocol {
    func showPurchaseProviders(
        from view: ControllerBackedProtocol?,
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
        from view: ControllerBackedProtocol?,
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

    func presentSuccessAlert(from view: ControllerBackedProtocol?, message: String) {
        let alertController = ModalAlertFactory.createMultilineSuccessAlert(message)
        view?.controller.present(alertController, animated: true)
    }
}

extension BuyAssetOperationWireframe: AssetsSearchWireframeProtocol {
    func close(view: AssetsSearchViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true)
    }
}
