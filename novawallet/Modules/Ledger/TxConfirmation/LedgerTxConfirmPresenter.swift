import Foundation
import IrohaCrypto
import SoraFoundation

final class LedgerTxConfirmPresenter: LedgerPerformOperationPresenter {
    let completion: TransactionSigningClosure

    var wireframe: LedgerTxConfirmWireframeProtocol? {
        baseWireframe as? LedgerTxConfirmWireframeProtocol
    }

    init(
        chainName: String,
        interactor: LedgerPerformOperationInputProtocol,
        wireframe: LedgerTxConfirmWireframeProtocol,
        completion: @escaping TransactionSigningClosure,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.completion = completion

        super.init(
            chainName: chainName,
            interactor: interactor,
            baseWireframe: wireframe,
            localizationManager: localizationManager
        )
    }
}

extension LedgerTxConfirmPresenter: LedgerTxConfirmInteractorOutputProtocol {
    func didReceiveSigning(result: Result<IRSignatureProtocol, Error>, for _: UUID) {
        wireframe?.complete(on: view)

        switch result {
        case let .success(signature):
            completion(.success(signature))
        case let .failure(error):
            completion(.failure(error))
        }
    }
}
