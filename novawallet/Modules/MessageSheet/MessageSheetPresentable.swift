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
        let object = objc_getAssociatedObject(view, &MessageSheetPresentableConstants.viewKey) as? WeakWrapper
        return object?.target as? MessageSheetViewProtocol
    }

    func setMessageSheetView(_ newMessageSheetView: MessageSheetViewProtocol?, for view: ControllerBackedProtocol) {
        let object: WeakWrapper?

        if let newMessageSheetView = newMessageSheetView {
            object = WeakWrapper(target: newMessageSheetView)
        } else {
            object = nil
        }

        objc_setAssociatedObject(
            view,
            &MessageSheetPresentableConstants.viewKey,
            object,
            .OBJC_ASSOCIATION_RETAIN
        )
    }

    func transitToMessageSheet(_ newMessageSheetView: MessageSheetViewProtocol, on view: ControllerBackedProtocol) {
        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.fearless)

        newMessageSheetView.controller.modalTransitioningFactory = factory
        newMessageSheetView.controller.modalPresentationStyle = .custom

        if
            let messageSheet = getMessageSheetForHolder(view: view),
            messageSheet.controller.presentingViewController != nil,
            !messageSheet.controller.isBeingDismissed {
            view.controller.dismiss(animated: true)

            setMessageSheetView(newMessageSheetView, for: view)

            view.controller.present(newMessageSheetView.controller, animated: true)
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
