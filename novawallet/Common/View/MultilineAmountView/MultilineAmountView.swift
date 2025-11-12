import UIKit
import UIKit_iOS
import Foundation_iOS

class MultilineAmountView: TitleAmountView {
    var title: LocalizableResource<String>? {
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

        setupLocalization()
        applyLocalization()
        setupStyle()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupLocalization() {
        title = LocalizableResource<String> { _ in "" }
    }

    private func applyLocalization() {
        titleLabel.text = title?.value(for: locale)
    }

    private func setupStyle() {
        titleView.iconWidth = .zero
        titleView.detailsView.iconWidth = .zero
        titleView.imageView.isHidden = true
        titleView.detailsView.imageView.isHidden = true
    }
}
