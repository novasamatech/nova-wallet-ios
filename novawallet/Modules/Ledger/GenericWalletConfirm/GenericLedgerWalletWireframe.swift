import Foundation

final class GenericLedgerWalletWireframe: GenericLedgerWalletWireframeProtocol, MessageSheetPresentable {
    let flow: WalletCreationFlow

    init(flow: WalletCreationFlow) {
        self.flow = flow
    }

    func showAddressVerification(
        on view: HardwareWalletAddressesViewProtocol?,
        deviceName: String,
        deviceModel: LedgerDeviceModel,
        addresses: [HardwareWalletAddressScheme: AccountAddress],
        cancelClosure: @escaping () -> Void
    ) {
        guard
            let view = view,
            let confirmationView = LedgerMessageSheetViewFactory.createVerifyLedgerView(
                for: deviceName,
                deviceModel: deviceModel,
                addresses: addresses,
                cancelClosure: cancelClosure
            ) else {
            return
        }

        transitToMessageSheet(confirmationView, on: view)
    }

    func procced(from view: HardwareWalletAddressesViewProtocol?, walletModel: PolkadotLedgerWalletModel) {
        guard
            let createView = LedgerWalletConfirmViewFactory.createGenericView(
                for: walletModel,
                flow: flow
            ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(createView.controller, animated: true)
    }
}
