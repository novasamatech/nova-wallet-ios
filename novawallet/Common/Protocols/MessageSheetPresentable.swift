import Foundation
import SoraUI

protocol MessageSheetPresentable {
    func presentNoSigningView(from presentationView: ControllerBackedProtocol, completion: @escaping () -> Void)
    func presentParitySignerNotSupportedView(
        from presentationView: ControllerBackedProtocol,
        completion: @escaping () -> Void
    )
}

extension MessageSheetPresentable {
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
        guard let confirmationView = MessageSheetPresentableFactory.createNoSigningView(with: completion) else {
            return
        }

        presentationView.controller.present(confirmationView.controller, animated: true, completion: nil)
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
        guard let confirmationView = MessageSheetPresentableFactory.createParitySignerNotSupportedView(
            with: completion
        ) else {
            return
        }

        presentationView.controller.present(confirmationView.controller, animated: true, completion: nil)
    }
}

enum MessageSheetPresentableFactory {
    static func createNoSigningView(with completion: @escaping () -> Void) -> MessageSheetViewProtocol? {
        guard let confirmationView = MessageSheetViewFactory.createNoSigningView(with: completion) else {
            return nil
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.fearless)

        confirmationView.controller.modalTransitioningFactory = factory
        confirmationView.controller.modalPresentationStyle = .custom

        return confirmationView
    }

    static func createParitySignerNotSupportedView(with completion: @escaping () -> Void) -> MessageSheetViewProtocol? {
        guard let confirmationView = MessageSheetViewFactory.createParitySignerNotSupportedView(with: completion) else {
            return nil
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.fearless)

        confirmationView.controller.modalTransitioningFactory = factory
        confirmationView.controller.modalPresentationStyle = .custom

        return confirmationView
    }
}
