import UIKit
import SoraUI
import SoraFoundation

class NetworkFeeView: TitleAmountView {
    var title: LocalizableResource<String> = LocalizableResource { locale in
        R.string.localizable.commonNetworkFee(preferredLanguages: locale.rLanguages)
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
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func applyLocalization() {
        titleLabel.text = title.value(for: locale)
    }
}
