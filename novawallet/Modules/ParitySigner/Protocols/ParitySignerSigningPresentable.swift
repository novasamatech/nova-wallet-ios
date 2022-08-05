import Foundation
import IrohaCrypto

typealias ParitySignerResult = Result<IRSignatureProtocol, Error>
typealias ParitySignerSigningClosure = (ParitySignerResult) -> Void

protocol TransactionSigningPresenting: AnyObject {
    func presentParitySignerFlow(for data: Data, completion: ParitySignerSigningClosure)
}

final class TransactionSigningPresenter: TransactionSigningPresenting {
    weak var view: UIViewController?

    init(view: UIViewController? = nil) {
        self.view = view
    }

    func presentParitySignerFlow(for data: Data, completion: ParitySignerSigningClosure) {
        let defaultRootViewController = UIApplication.shared.delegate?.window??.rootViewController
        let optionalController = view ?? defaultRootViewController?.topModalViewController ?? defaultRootViewController

        guard let controller = optionalController else {
            completion(.failure(CommonError.dataCorruption))
            return
        }

        guard let txQrView = ParitySignerTxQrViewFactory.createView(with: data, completion: completion) else {
            return
        }

        let navigationController = FearlessNavigationController(rootViewController: txQrView.controller)

        controller.present(navigationController, animated: true)
    }
}
