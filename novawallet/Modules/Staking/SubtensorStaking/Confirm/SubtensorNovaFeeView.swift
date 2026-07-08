import Foundation_iOS

/// A `MultilineAmountView` subclass whose title reads "Nova Wallet fee" from the
/// Subtensor localized strings, shown with the fee amount. Used on the stake /
/// unstake setup and confirm fee rows. The 0.3% rate is disclosed separately via
/// the "Includes …" caption beneath the fees, mirroring Hydration swaps. Mirrors
/// the pattern of `NetworkFeeView`.
final class SubtensorNovaFeeView: MultilineAmountView {
    override func setupLocalization() {
        title = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.subtensorNovaFeeTitle()
        }
    }
}
