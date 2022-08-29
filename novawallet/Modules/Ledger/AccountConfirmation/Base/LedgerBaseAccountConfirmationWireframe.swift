import Foundation
import SoraUI

class LedgerBaseAccountConfirmationWireframe {
    func showAddressVerification(
        on view: LedgerAccountConfirmationViewProtocol?,
        deviceName: String,
        address: AccountAddress
    ) {
        guard
            let confirmationView = LedgerBottomSheetViewFactory.createVerifyLedgerView(
                for: deviceName,
                address: address
            ) else {
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
