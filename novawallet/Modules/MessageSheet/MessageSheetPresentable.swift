import Foundation
import SoraUI

protocol MessageSheetPresentable: AnyObject {
    func transitToMessageSheet(_ newMessageSheetView: MessageSheetViewProtocol, on view: ControllerBackedProtocol)

    func closeMessageSheet(on view: ControllerBackedProtocol)

    func presentNoSigningView(from presentationView: ControllerBackedProtocol, completion: @escaping () -> Void)

    func presentParitySignerNotSupportedView(
        from presentationView: ControllerBackedProtocol,
        completion: @escaping () -> Void
    )
}

private enum MessageSheetPresentableConstants {
    static var viewKey: String = "com.novawallet.message.sheet.view"
}

extension MessageSheetPresentable {
    func getMessageSheetForHolder(view: ControllerBackedProtocol) -> MessageSheetViewProtocol? {
        objc_getAssociatedObject(
            view,
            &MessageSheetPresentableConstants.viewKey
        ) as? MessageSheetViewProtocol
    }

    func setMessageSheetView(_ newMessageSheetView: MessageSheetViewProtocol?, for view: ControllerBackedProtocol) {
        objc_setAssociatedObject(
            view,
            &MessageSheetPresentableConstants.viewKey,
            newMessageSheetView,
            .OBJC_ASSOCIATION_ASSIGN
        )
    }

    func transitToMessageSheet(_ newMessageSheetView: MessageSheetViewProtocol, on view: ControllerBackedProtocol) {
        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.fearless)

        newMessageSheetView.controller.modalTransitioningFactory = factory
        newMessageSheetView.controller.modalPresentationStyle = .custom

        if getMessageSheetForHolder(view: view) != nil {
            view.controller.dismiss(animated: false)

            setMessageSheetView(newMessageSheetView, for: view)

            view.controller.present(newMessageSheetView.controller, animated: false)
        } else {
            setMessageSheetView(newMessageSheetView, for: view)

            view.controller.present(newMessageSheetView.controller, animated: true)
        }
    }

    func closeMessageSheet(on view: ControllerBackedProtocol) {
        if getMessageSheetForHolder(view: view) != nil {
            setMessageSheetView(nil, for: view)
            view.controller.dismiss(animated: true)
        }
    }

    func presentDismissingNoSigningView(from presentationView: ControllerBackedProtocol?) {
        guard let presentationView = presentationView else {
            return
        }

        presentNoSigningView(from: presentationView) {
            let presenter = presentationView.controller.presentingViewController
            presenter?.dismiss(animated: true, completion: nil)
        }
    }

    func presentPopingNoSigningView(from presentationView: ControllerBackedProtocol?) {
        guard let presentationView = presentationView else {
            return
        }

        presentNoSigningView(from: presentationView) {
            presentationView.controller.navigationController?.popToRootViewController(animated: true)
        }
    }

    func presentNoSigningView(from presentationView: ControllerBackedProtocol, completion: @escaping () -> Void) {
        guard let confirmationView = MessageSheetViewFactory.createNoSigningView(with: completion) else {
            return
        }

        transitToMessageSheet(confirmationView, on: presentationView)
    }

    func presentDismissingParitySignerNotSupportedView(from presentationView: ControllerBackedProtocol?) {
        guard let presentationView = presentationView else {
            return
        }

        presentParitySignerNotSupportedView(from: presentationView) {
            let presenter = presentationView.controller.presentingViewController
            presenter?.dismiss(animated: true, completion: nil)
        }
    }

    func presentPopingParitySignerNotSupportedView(from presentationView: ControllerBackedProtocol?) {
        guard let presentationView = presentationView else {
            return
        }

        presentParitySignerNotSupportedView(from: presentationView) {
            presentationView.controller.navigationController?.popToRootViewController(animated: true)
        }
    }

    func presentParitySignerNotSupportedView(
        from presentationView: ControllerBackedProtocol,
        completion: @escaping () -> Void
    ) {
        guard let confirmationView = MessageSheetViewFactory.createParitySignerNotSupportedView(
            with: completion
        ) else {
            return
        }

        transitToMessageSheet(confirmationView, on: presentationView)
    }
}
