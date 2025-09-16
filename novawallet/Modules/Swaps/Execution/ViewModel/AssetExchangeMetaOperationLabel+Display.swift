import Foundation

extension AssetExchangeMetaOperationLabel {
    func getTitle(for locale: Locale) -> String {
        switch self {
        case .swap:
            R.string(preferredLanguages: locale.rLanguages).localizable.swapsLabelSwap()
        case .transfer:
            R.string(preferredLanguages: locale.rLanguages).localizable.swapsLabelCrosschain()
        }
    }
}
