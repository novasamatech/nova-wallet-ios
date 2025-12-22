import Foundation

extension HardwareWalletAddressScheme {
    func createTitle(for locale: Locale) -> String {
        switch self {
        case .substrate:
            R.string(preferredLanguages: locale.rLanguages).localizable.commonSubstrateAddressTitle()
        case .evm:
            R.string(preferredLanguages: locale.rLanguages).localizable.commonEvmAddress()
        }
    }
}
