import Foundation
import SoraUI

class LedgerBaseAccountConfirmationWireframe: MessageSheetPresentable {
    func showAddressVerification(
        on view: LedgerAccountConfirmationViewProtocol?,
        deviceName: String,
        address: AccountAddress,
        cancelClosure: @escaping () -> Void
    ) {
        guard
            let view = view,
            let confirmationView = LedgerMessageSheetViewFactory.createVerifyLedgerView(
                for: deviceName,
                address: address,
                cancelClosure: cancelClosure
            ) else {
            return
        }

        transitToMessageSheet(confirmationView, on: view)
    }
}
