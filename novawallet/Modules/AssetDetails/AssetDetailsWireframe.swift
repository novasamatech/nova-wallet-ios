import Foundation
import UIKit
import SoraUI

final class AssetDetailsWireframe: AssetDetailsWireframeProtocol {
    weak var prsentedViewController: UIViewController?

    func showPurchaseTokens(from _: AssetDetailsViewProtocol?, action _: PurchaseAction) {}

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
        let closeButtonItem = UIBarButtonItem(
            image: R.image.iconClose()!,
            style: .plain,
            target: self,
            action: #selector(closeModalController)
        )

        let fearlessNavigationController = FearlessNavigationController(rootViewController: transferSetupView.controller)
        transferSetupView.controller.navigationItem.leftBarButtonItem = closeButtonItem
        navigationController.present(fearlessNavigationController, animated: true)
        prsentedViewController = fearlessNavigationController
    }

    @objc func closeModalController() {
        prsentedViewController?.dismiss(animated: true)
    }

    func showReceiveTokens(from _: AssetDetailsViewProtocol?) {}

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

    func showLocks(from _: AssetDetailsViewProtocol?) {}

    func showNoSigning(from view: AssetDetailsViewProtocol?) {
        guard let confirmationView = MessageSheetViewFactory.createNoSigningView(with: {}) else {
            return
        }
        present(confirmationView, from: view)
    }

    func showLedgerNotSupport(for tokenName: String, from view: AssetDetailsViewProtocol?) {
        guard let confirmationView = LedgerMessageSheetViewFactory.createLedgerNotSupportTokenView(
            for: tokenName,
            cancelClosure: nil
        ) else {
            return
        }
        present(confirmationView, from: view)
    }

    private func present(_ vc: ControllerBackedProtocol, from view: AssetDetailsViewProtocol?) {
        guard let navigationController = view?.controller.navigationController else {
            return
        }
        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.fearless)
        vc.controller.modalTransitioningFactory = factory
        vc.controller.modalPresentationStyle = .custom
        navigationController.present(vc.controller, animated: true)
    }
}
