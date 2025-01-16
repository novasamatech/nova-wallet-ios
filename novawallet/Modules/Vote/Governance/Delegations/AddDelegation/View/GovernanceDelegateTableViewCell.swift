import UIKit
import UIKit_iOS

typealias GovernanceDelegateTableViewCell = BlurredTableViewCell<GovernanceDelegateView>

extension GovernanceDelegateTableViewCell {
    typealias Model = GovernanceDelegateView.Model

    func bind(viewModel: Model, locale: Locale) {
        view.bind(viewModel: viewModel, locale: locale)
    }

    func applyStyle() {
        shouldApplyHighlighting = true
        contentInsets = .init(top: 4, left: 16, bottom: 4, right: 16)
        innerInsets = .init(top: 12, left: 12, bottom: 12, right: 12)
        backgroundBlurView.sideLength = 12
    }
}
