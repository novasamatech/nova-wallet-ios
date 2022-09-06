import Foundation
import CommonWallet
import SoraUI

final class NoKeysCommand: WalletCommandProtocol {
    func execute() throws {
        guard let confirmationView = MessageSheetViewFactory.createNoSigningView(with: {}) else {
            return
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.fearless)

        confirmationView.controller.modalTransitioningFactory = factory
        confirmationView.controller.modalPresentationStyle = .custom

        let presentationController = UIApplication.shared.delegate?.window??.rootViewController
        presentationController?.present(confirmationView.controller, animated: true)
    }
}
