import UIKit

extension TitleHorizontalMultiValueView {
    struct Model {
        let title: String
        let subtitle: String
        let value: String
    }

    func bind(viewModel: LoadableViewModelState<Model>) {
        titleView.text = viewModel.value?.title
        detailsTitleLabel.text = viewModel.value?.subtitle
        detailsValueLabel.text = viewModel.value?.value
    }

    func bind(balance: Model) {
        titleView.text = balance.title
        detailsTitleLabel.text = balance.subtitle
        detailsValueLabel.text = balance.value
    }
}
