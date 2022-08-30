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
}
