import Foundation
import SoraUI

class LedgerBaseAccountConfirmationWireframe: MessageSheetPresentable {
    func showAddressVerification(
        on view: LedgerAccountConfirmationViewProtocol?,
        deviceName: String,
        address: AccountAddress
    ) {
        guard
            let view = view,
            let confirmationView = LedgerMessageSheetViewFactory.createVerifyLedgerView(
                for: deviceName,
                address: address
            ) else {
            return
        }

        transitToMessageSheet(confirmationView, on: view)
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
