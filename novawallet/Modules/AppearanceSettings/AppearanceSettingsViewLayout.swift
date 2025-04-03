import UIKit
import UIKit_iOS

final class AppearanceSettingsViewLayout: ScrollableContainerLayoutView {
    let tokenIconsView = AppearanceSettingsIconsView()

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setupLayout() {
        super.setupLayout()

        addArrangedSubview(tokenIconsView)
    }
}

// MARK: Private

private extension AppearanceSettingsViewLayout {
    func applyLocalization() {
        tokenIconsView.applyLocalization(for: locale)
    }
}
