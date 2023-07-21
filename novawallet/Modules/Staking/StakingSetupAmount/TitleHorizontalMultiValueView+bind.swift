import UIKit

extension TitleHorizontalMultiValueView {
    struct RewardModel {
        let title: String
        let subtitle: AccentTextModel
    }

    func bind(viewModel: LoadableViewModelState<RewardModel>) {
        switch viewModel {
        case .loading:
            // TODO:
            break
        case let .cached(value), let .loaded(value):
            detailsTitleLabel.text = value.title
            detailsValueLabel.bind(
                model: value.subtitle,
                with: .init(
                    textColor: detailsTitleLabel.textColor,
                    accentTextColor: R.color.colorTextPositive()!,
                    font: .caption1
                )
            )
        }
    }
}
