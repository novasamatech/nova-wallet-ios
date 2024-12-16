import UIKit

protocol CopyAddressPresentable {
    func copyAddress(
        from view: ControllerBackedProtocol?,
        address: String,
        locale: Locale
    )
}

extension CopyAddressPresentable where Self: ModalAlertPresenting {
    func copyAddress(
        from view: ControllerBackedProtocol?,
        address: String,
        locale: Locale
    ) {
        UIPasteboard.general.string = address

        let title = R.string.localizable.commonAddressCoppied(preferredLanguages: locale.rLanguages)

        presentSuccessNotification(
            title,
            from: view
        )
    }
}
