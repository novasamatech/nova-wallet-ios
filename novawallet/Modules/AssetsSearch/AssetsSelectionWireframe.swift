import UIKit
import SoraUI

final class AssetsSelectionWireframe: AssetsSearchWireframeProtocol {
    private let operation: TokenOperation

    init(operation: TokenOperation) {
        self.operation = operation
    }

    func finish(
        selection: ChainAsset,
        view: AssetsSearchViewProtocol?
    ) {
        guard let transferSetupView = TransferSetupViewFactory.createView(
            from: selection,
            recepient: nil,
            commandFactory: nil
        ) else {
            return
        }

        guard let navigationController = view?.controller.navigationController else {
            return
        }

        navigationController.pushViewController(transferSetupView.controller, animated: true)
    }

    func cancel(from view: AssetsSearchViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true)
    }

    func showNoLedgerSupport(from view: AssetsSearchViewProtocol?, tokenName: String) {
        guard let confirmationView = LedgerMessageSheetViewFactory.createLedgerNotSupportTokenView(
            for: tokenName,
            cancelClosure: nil
        ) else {
            return
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)

        confirmationView.controller.modalTransitioningFactory = factory
        confirmationView.controller.modalPresentationStyle = .custom

        view?.controller.present(confirmationView.controller, animated: true)
    }

    func showNoKeys(from view: AssetsSearchViewProtocol?) throws {
        guard let confirmationView = MessageSheetViewFactory.createNoSigningView(with: {}) else {
            return
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)

        confirmationView.controller.modalTransitioningFactory = factory
        confirmationView.controller.modalPresentationStyle = .custom

        view?.controller.present(confirmationView.controller, animated: true)
    }
}
