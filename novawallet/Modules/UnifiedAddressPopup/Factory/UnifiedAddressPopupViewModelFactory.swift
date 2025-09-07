import Foundation

extension UnifiedAddressPopup {
    class ViewModelFactory {
        let newAddress: AccountAddress
        let legacyAddress: AccountAddress
        let applicationConfig: ApplicationConfigProtocol

        init(
            newAddress: AccountAddress,
            legacyAddress: AccountAddress,
            applicationConfig: ApplicationConfigProtocol
        ) {
            self.newAddress = newAddress
            self.legacyAddress = legacyAddress
            self.applicationConfig = applicationConfig
        }
    }
}

extension UnifiedAddressPopup.ViewModelFactory {
    func createViewModel(
        dontShowAgain: Bool,
        locale: Locale
    ) -> UnifiedAddressPopup.ViewModel {
        let languages = locale.rLanguages

        let title = R.string(preferredLanguages: languages).localizable.unifiedAddressPopupTitle()
        let subtitle = R.string(preferredLanguages: languages).localizable.unifiedAddressPopupSubtitle()
        let wikiText = R.string(preferredLanguages: languages).localizable.commonLearnMore()
        let checkboxText = R.string(preferredLanguages: languages).localizable.unifiedAddressPopupCheckboxText()

        let newFormatText = R.string.localizable
            .unifiedAddressNewFormat(preferredLanguages: languages)
            .uppercased()
        let legacyFormatText = R.string.localizable
            .unifiedAddressLegacyFormat(preferredLanguages: languages)
            .uppercased()
        let newAddress = UnifiedAddressPopup.AddressViewModel(
            formatText: newFormatText,
            addressText: newAddress
        )

        let legacyAddress = UnifiedAddressPopup.AddressViewModel(
            formatText: legacyFormatText,
            addressText: legacyAddress
        )

        let buttonText = R.string(preferredLanguages: languages).localizable.commonOk().uppercased()
        let wikiURL = applicationConfig.unifiedAddressWikiURL

        return UnifiedAddressPopup.ViewModel(
            titleText: title,
            subtitleText: subtitle,
            wikiText: wikiText,
            wikiURL: wikiURL,
            newAddress: newAddress,
            legacyAddress: legacyAddress,
            checkboxText: checkboxText,
            checkboxSelected: dontShowAgain,
            buttonText: buttonText
        )
    }
}
