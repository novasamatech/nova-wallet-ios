import Foundation
import IrohaCrypto

typealias TransactionSigningResult = Result<IRSignatureProtocol, Error>
typealias TransactionSigningClosure = (TransactionSigningResult) -> Void

protocol TransactionSigningPresenting: AnyObject {
    func presentParitySignerFlow(
        for data: Data,
        metaId: String,
        chainId: ChainModel.Id,
        completion: @escaping TransactionSigningClosure
    )

    func presentLedgerFlow(
        for data: Data,
        metaId: String,
        chainId: ChainModel.Id,
        completion: @escaping TransactionSigningClosure
    )
}

final class TransactionSigningPresenter: TransactionSigningPresenting {
    weak var view: UIViewController?

    init(view: UIViewController? = nil) {
        self.view = view
    }

    private func present(signingView: ControllerBackedProtocol, completion: @escaping TransactionSigningClosure) {
        let defaultRootViewController = UIApplication.shared.delegate?.window??.rootViewController
        let optionalController = view ?? defaultRootViewController?.topModalViewController ?? defaultRootViewController

        guard let controller = optionalController else {
            completion(.failure(CommonError.dataCorruption))
            return
        }

        let barSettings = NavigationBarSettings.defaultSettings.bySettingCloseButton(false)

        let navigationController = ImportantFlowViewFactory.createNavigation(
            from: signingView.controller,
            barSettings: barSettings
        ) {
            completion(.failure(HardwareSigningError.signingCancelled))
        }

        controller.present(navigationController, animated: true)
    }

    func presentParitySignerFlow(
        for data: Data,
        metaId: String,
        chainId: ChainModel.Id,
        completion: @escaping TransactionSigningClosure
    ) {
        guard let paritySignerView = ParitySignerTxQrViewFactory.createView(
            with: data,
            metaId: metaId,
            chainId: chainId,
            completion: completion
        ) else {
            completion(.failure(CommonError.dataCorruption))
            return
        }

        present(signingView: paritySignerView, completion: completion)
    }

    func presentLedgerFlow(
        for data: Data,
        metaId: String,
        chainId: ChainModel.Id,
        completion: @escaping TransactionSigningClosure
    ) {
        guard
            let ledgerView = LedgerTxConfirmViewFactory.createView(
                with: data,
                metaId: metaId,
                chainId: chainId,
                completion: completion
            ) else {
            completion(.failure(CommonError.dataCorruption))
            return
        }

        present(signingView: ledgerView, completion: completion)
    }
}
