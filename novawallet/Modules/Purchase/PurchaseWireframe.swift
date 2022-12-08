import Foundation
import CommonWallet
import SoraFoundation

final class PurchaseWireframe: PurchaseWireframeProtocol {
    private weak var delegate: PurchaseDelegate?

    init(delegate: PurchaseDelegate) {
        self.delegate = delegate
    }

    func complete(from view: PurchaseViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true) {
            DispatchQueue.main.async {
                self.delegate?.purchaseDidComplete()
            }
        }
    }
}

protocol PurchaseDelegate: AnyObject {
    func purchaseDidComplete()
}
