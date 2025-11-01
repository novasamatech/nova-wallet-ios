import Foundation_iOS

final class GiftAmountView: MultilineAmountView {
    override func setupLocalization() {
        title = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.giftTransferConfirmYourGift()
        }
    }
}
