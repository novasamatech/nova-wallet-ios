import UIKit

extension SwapNetworkFeeViewCell {
    func bind(costBasisRow viewModel: SubtensorCostBasisRowViewModel, locale: Locale) {
        isAccessibilityElement = true
        accessibilityLabel = titleButton.imageWithTitleView?.title

        switch viewModel {
        case .hidden:
            isHidden = true
        case .loading:
            isHidden = false
            accessibilityValue = nil
            bind(loadableViewModel: .loading)
        case let .value(value):
            isHidden = false
            accessibilityValue = value.accessibilityValue(for: locale)
            valueTopButton.imageWithTitleView?.titleColor = value.tone.textColor

            let info = NetworkFeeInfoViewModel(
                isEditable: false,
                balanceViewModel: BalanceViewModel(amount: value.amount, price: value.detail)
            )

            bind(loadableViewModel: .loaded(value: info))

            valueTopButton.imageWithTitleView?.iconImage = value.trend?.arrowImage
            valueTopButton.invalidateLayout()
        }
    }
}

private extension SubtensorAvgBuyPriceTrend {
    static let risingArrowImage = SubtensorAvgBuyPriceTrend.rising.renderArrowImage()
    static let fallingArrowImage = SubtensorAvgBuyPriceTrend.falling.renderArrowImage()

    var arrowImage: UIImage? {
        switch self {
        case .rising:
            return Self.risingArrowImage
        case .falling:
            return Self.fallingArrowImage
        case .unchanged:
            return nil
        }
    }

    func renderArrowImage() -> UIImage? {
        guard let arrow else {
            return nil
        }

        var attributes: [NSAttributedString.Key: Any] = [.font: UIFont.caption2]
        attributes[.foregroundColor] = arrow.tone.textColor

        let glyph = NSAttributedString(string: arrow.glyph, attributes: attributes)

        return UIGraphicsImageRenderer(size: glyph.size()).image { _ in
            glyph.draw(at: .zero)
        }
    }
}
