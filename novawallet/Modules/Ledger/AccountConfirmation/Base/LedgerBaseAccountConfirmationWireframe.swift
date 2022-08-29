import Foundation
import SoraUI

class LedgerBaseAccountConfirmationWireframe {
    func showAddressVerification(on view: LedgerAccountConfirmationViewProtocol?, deviceName: String) {
        guard let confirmationView = LedgerBottomSheetViewFactory.createVerifyLedgerView(for: deviceName) else {
            return
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.fearless)

        confirmationView.controller.modalTransitioningFactory = factory
        confirmationView.controller.modalPresentationStyle = .custom

        view?.controller.navigationController?.present(confirmationView.controller, animated: true, completion: nil)
    }

    func closeAddressVerification(on view: LedgerAccountConfirmationViewProtocol?) {
        guard let navigationController = view?.controller.navigationController else {
            return
        }

        let sheetPresented = navigationController.presentedViewController is MessageSheetViewProtocol

        if sheetPresented {
            navigationController.dismiss(animated: true, completion: nil)
        }
    }
}
