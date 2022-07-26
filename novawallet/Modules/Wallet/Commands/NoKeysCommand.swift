import Foundation
import CommonWallet
import SoraUI

final class NoKeysCommand: WalletCommandProtocol {
    func execute() throws {
        guard let confirmationView = NoSigningPresentableFactory.createNoSigningView(with: {}) else {
            return
        }

        let presentationController = UIApplication.shared.delegate?.window??.rootViewController
        presentationController?.present(confirmationView.controller, animated: true)
    }
}
