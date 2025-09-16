import UIKit
import UIKit_iOS
import Foundation_iOS

class NetworkFeeView: TitleAmountView {
    var title: LocalizableResource<String> = LocalizableResource { locale in
        R.string(preferredLanguages: locale.rLanguages).localizable.commonNetworkFee()
    } {
        didSet {
            applyLocalization()
        }
    }

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        applyLocalization()
        setupStyle()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func applyLocalization() {
        titleLabel.text = title.value(for: locale)
    }

    private func setupStyle() {
        titleView.iconWidth = .zero
        titleView.detailsView.iconWidth = .zero
        titleView.imageView.isHidden = true
        titleView.detailsView.imageView.isHidden = true
    }
}
