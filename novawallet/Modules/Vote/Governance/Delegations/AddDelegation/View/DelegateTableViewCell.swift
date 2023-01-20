import UIKit
import SoraUI

typealias DelegateTableViewCell = BlurredTableViewCell<DelegateView>

extension DelegateTableViewCell {
    typealias Model = DelegateView.Model

    func bind(viewModel: Model, locale: Locale) {
        view.bind(viewModel: viewModel, locale: locale)
    }

    func applyStyle() {
        contentInsets = .init(top: 4, left: 0, bottom: 4, right: 0)
        innerInsets = .init(top: 12, left: 12, bottom: 12, right: 12)
        backgroundBlurView.sideLength = 12
    }
}
