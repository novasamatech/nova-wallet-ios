import UIKit

extension SwapNetworkFeeViewCell {
    func bind(costBasisRow viewModel: SubtensorRowState<SubtensorCostBasisValueViewModel>, locale: Locale) {
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

            let arrow = value.trend?.arrow
            valueTopButton.imageWithTitleView?.titleColor = (arrow?.tone ?? value.tone).textColor
            valueTopButton.imageWithTitleView?.titleFont = arrow != nil ? .caption2 : .regularFootnote

            let info = NetworkFeeInfoViewModel(
                isEditable: false,
                balanceViewModel: BalanceViewModel(
                    amount: arrow.map { $0.glyph + " " + value.amount } ?? value.amount,
                    price: value.detail
                )
            )

            bind(loadableViewModel: .loaded(value: info))
        }
    }
}
