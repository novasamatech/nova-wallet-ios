import UIKit

extension SwapNetworkFeeViewCell {
    func bind(costBasisRow viewModel: SubtensorCostBasisRowViewModel) {
        switch viewModel {
        case .hidden:
            isHidden = true
        case .loading:
            isHidden = false
            bind(loadableViewModel: .loading)
        case let .value(value):
            isHidden = false
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
    var arrowImage: UIImage? {
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
