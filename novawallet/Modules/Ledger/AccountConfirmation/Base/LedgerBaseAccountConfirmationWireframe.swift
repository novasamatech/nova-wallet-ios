import Foundation
import UIKit_iOS

class LedgerBaseAccountConfirmationWireframe: MessageSheetPresentable {
    func showAddressVerification(
        on view: LedgerAccountConfirmationViewProtocol?,
        deviceName: String,
        deviceModel: LedgerDeviceModel,
        address: AccountAddress,
        cancelClosure: @escaping () -> Void
    ) {
        guard
            let view = view,
            let confirmationView = LedgerMessageSheetViewFactory.createVerifyLedgerView(
                for: deviceName,
                deviceModel: deviceModel,
                address: address,
                cancelClosure: cancelClosure
            ) else {
            return
        }

        transitToMessageSheet(confirmationView, on: view)
    }
}
