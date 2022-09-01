import Foundation
import CommonWallet
import SoraUI

final class NoLedgerSupportCommand: WalletCommandProtocol {
    let tokenName: String

    init(tokenName: String) {
        self.tokenName = tokenName
    }

    func execute() throws {
        guard let confirmationView = LedgerMessageSheetViewFactory.createLedgerNotSupportTokenView(
            for: tokenName,
            cancelClosure: nil
        ) else {
            return
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.fearless)

        confirmationView.controller.modalTransitioningFactory = factory
        confirmationView.controller.modalPresentationStyle = .custom

        let presentationController = UIApplication.shared.delegate?.window??.rootViewController
        presentationController?.present(confirmationView.controller, animated: true)
    }
}
