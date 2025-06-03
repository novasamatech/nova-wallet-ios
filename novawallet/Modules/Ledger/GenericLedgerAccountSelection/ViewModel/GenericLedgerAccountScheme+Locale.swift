import Foundation

extension HardwareWalletAddressScheme {
    func createTitle(for locale: Locale) -> String {
        switch self {
        case .substrate:
            R.string.localizable.commonSubstrateAddressTitle(
                preferredLanguages: locale.rLanguages
            )
        case .evm:
            R.string.localizable.commonEvmAddress(
                preferredLanguages: locale.rLanguages
            )
        }
    }
}
