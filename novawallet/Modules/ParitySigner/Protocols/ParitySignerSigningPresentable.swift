import Foundation
import IrohaCrypto

typealias TransactionSigningResult = Result<IRSignatureProtocol, Error>
typealias TransactionSigningClosure = (TransactionSigningResult) -> Void

protocol TransactionSigningPresenting: AnyObject {
    func presentParitySignerFlow(
        for data: Data,
        metaId: String,
        chainId: ChainModel.Id,
        completion: TransactionSigningClosure
    )
}

final class TransactionSigningPresenter: TransactionSigningPresenting {
    weak var view: UIViewController?

    init(view: UIViewController? = nil) {
        self.view = view
    }

    func presentParitySignerFlow(
        for data: Data,
        metaId: String,
        chainId: ChainModel.Id,
        completion: TransactionSigningClosure
    ) {
        let defaultRootViewController = UIApplication.shared.delegate?.window??.rootViewController
        let optionalController = view ?? defaultRootViewController?.topModalViewController ?? defaultRootViewController

        guard let controller = optionalController else {
            completion(.failure(CommonError.dataCorruption))
            return
        }

        guard let txQrView = ParitySignerTxQrViewFactory.createView(
            with: data,
            metaId: metaId,
            chainId: chainId,
            completion: completion
        ) else {
            return
        }

        let navigationController = FearlessNavigationController(rootViewController: txQrView.controller)

        controller.present(navigationController, animated: true)
    }
}
