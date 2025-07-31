import Foundation
import UIKit_iOS

protocol MessageSheetPresentable: AnyObject {
    func transitToMessageSheet(_ newMessageSheetView: MessageSheetViewProtocol, on view: ControllerBackedProtocol)

    func closeMessageSheet(on view: ControllerBackedProtocol)

    func presentNoSigningView(from presentationView: ControllerBackedProtocol, completion: @escaping () -> Void)

    func presentSignerNotSupportedView(
        from presentationView: ControllerBackedProtocol,
        type: NoSigningSupportType,
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
        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)

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

    func presentNoSigningView(from presentationView: ControllerBackedProtocol, completion: @escaping () -> Void) {
        guard let confirmationView = MessageSheetViewFactory.createNoSigningView(with: completion) else {
            return
        }

        transitToMessageSheet(confirmationView, on: presentationView)
    }

    func presentFeatureUnsupportedView(
        from presentationView: ControllerBackedProtocol,
        type: UnsupportedFeatureType,
        walletType: FeatureUnsupportedWalletType,
        completion: @escaping () -> Void
    ) {
        guard let confirmationView = MessageSheetViewFactory.createFeatureNotSupportedView(
            type: type,
            walletType: walletType,
            completionCallback: completion
        ) else {
            return
        }

        transitToMessageSheet(confirmationView, on: presentationView)
    }

    func presentSignerNotSupportedView(
        from presentationView: ControllerBackedProtocol,
        type: NoSigningSupportType,
        completion: @escaping () -> Void
    ) {
        guard let confirmationView = MessageSheetViewFactory.createSignerNotSupportedView(
            type: type,
            completionCallback: completion
        ) else {
            return
        }

        transitToMessageSheet(confirmationView, on: presentationView)
    }
}
