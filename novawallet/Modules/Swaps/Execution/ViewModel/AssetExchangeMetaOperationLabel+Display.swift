import Foundation

extension AssetExchangeMetaOperationLabel {
    func getTitle(for locale: Locale) -> String {
        switch self {
        case .swap:
            R.string.localizable.swapsLabelSwap(preferredLanguages: locale.rLanguages)
        case .transfer:
            R.string.localizable.swapsLabelCrosschain(preferredLanguages: locale.rLanguages)
        }
    }
}
