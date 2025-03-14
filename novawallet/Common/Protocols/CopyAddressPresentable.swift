import UIKit
import SoraKeystore

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

extension CopyAddressPresentable where Self: ModalAlertPresenting & UnifiedAddressPopupPresentable {
    func copyAddress(
        from view: ControllerBackedProtocol?,
        address: String,
        chain: ChainModel,
        locale: Locale
    ) {
        let hideUnifiedAddressPopup = SettingsManager.shared.hideUnifiedAddressPopup

        if
            let legacyAddress = try? address.toLegacySubstrateAddress(for: chain.chainFormat),
            !hideUnifiedAddressPopup {
            presentUnifiedAddressPopup(
                from: view,
                newAddress: address,
                legacyAddress: legacyAddress
            )
        } else {
            UIPasteboard.general.string = address

            let title = R.string.localizable.commonAddressCoppied(preferredLanguages: locale.rLanguages)

            presentSuccessNotification(
                title,
                from: view
            )
        }
    }
}
