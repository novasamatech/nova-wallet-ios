import Foundation
import SoraUI

protocol NoSigningPresentable {
    func presentNoSigningView(from presentationView: ControllerBackedProtocol, completion: @escaping () -> Void)
}

extension NoSigningPresentable {
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
        guard let confirmationView = NoSigningPresentableFactory.createNoSigningView(with: completion) else {
            return
        }

        presentationView.controller.present(confirmationView.controller, animated: true, completion: nil)
    }
}

enum NoSigningPresentableFactory {
    static func createNoSigningView(with completion: @escaping () -> Void) -> MessageSheetViewProtocol? {
        guard let confirmationView = MessageSheetViewFactory.createNoSigningView(with: completion) else {
            return nil
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.fearless)

        confirmationView.controller.modalTransitioningFactory = factory
        confirmationView.controller.modalPresentationStyle = .custom

        return confirmationView
    }
}
