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

        let title = R.string.localizable.unifiedAddressPopupTitle(preferredLanguages: languages)
        let subtitle = R.string.localizable.unifiedAddressPopupSubtitle(preferredLanguages: languages)
        let wikiText = R.string.localizable.commonLearnMore(preferredLanguages: languages)
        let checkboxText = R.string.localizable.unifiedAddressPopupCheckboxText(preferredLanguages: languages)

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

        let buttonText = R.string.localizable.commonOk(preferredLanguages: languages).uppercased()
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
