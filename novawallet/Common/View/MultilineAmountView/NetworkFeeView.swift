import Foundation_iOS

final class NetworkFeeView: MultilineAmountView {
    override func setupLocalization() {
        title = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.commonNetworkFee()
        }
    }
}
