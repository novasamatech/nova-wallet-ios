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
        let defaultRootViewController = UIApplication.shared.delegate?.window??.rootViewController
        self.view = view ?? defaultRootViewController?.topModalViewController ?? defaultRootViewController
    }

    func presentParitySignerFlow(for data: Data, completion: ParitySignerSigningClosure) {
        guard let view = view else {
            completion(.failure(CommonError.dataCorruption))
            return
        }

        guard let txQrView = ParitySignerTxQrViewFactory.createView(with: data, completion: completion) else {
            return
        }

        let navigationController = FearlessNavigationController(rootViewController: txQrView.controller)

        view.present(navigationController, animated: true)
    }
}
