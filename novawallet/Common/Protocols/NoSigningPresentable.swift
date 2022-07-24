import Foundation
import SoraUI

protocol NoSigningPresentable {
    func presentNoSigningView(from presentationView: ControllerBackedProtocol, completion: @escaping () -> Void)
}

extension NoSigningPresentable {
    func presentNoSigningView(from presentationView: ControllerBackedProtocol?) {
        guard let presentationView = presentationView else {
            return
        }

        presentNoSigningView(from: presentationView, completion: {})
    }

    func presentNoSigningView(from presentationView: ControllerBackedProtocol, completion: @escaping () -> Void) {
        guard let confirmationView = NoSigningViewFactory.createView(with: completion) else {
            return
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.fearless)

        confirmationView.controller.modalTransitioningFactory = factory
        confirmationView.controller.modalPresentationStyle = .custom

        presentationView.controller.present(confirmationView.controller, animated: true, completion: nil)
    }
}
