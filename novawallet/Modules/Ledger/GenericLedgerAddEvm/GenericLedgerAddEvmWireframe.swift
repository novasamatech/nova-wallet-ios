import Foundation

final class GenericLedgerAddEvmWireframe: GenericLedgerAddEvmWireframeProtocol {
    func showAddressVerification(
        on view: ControllerBackedProtocol?,
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

    func proceed(on view: ControllerBackedProtocol?) {
        guard let navigationController = view?.controller.navigationController else {
            return
        }

        MainTransitionHelper.transitToMainTabBarController(
            closing: navigationController,
            animated: true
        )
    }
}
