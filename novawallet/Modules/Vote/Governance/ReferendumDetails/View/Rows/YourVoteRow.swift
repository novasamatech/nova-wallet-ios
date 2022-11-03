import UIKit

final class YourVoteRow: RowView<GenericTitleValueView<YourVoteView, MultiValueView>> {
    struct Model {
        let vote: YourVoteView.Model
        let amount: MultiValueView.Model
    }

    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        borderView.borderType = .none
        rowContentView.titleView.apply(style: .ayeInverse)
        rowContentView.valueView.apply(style: .rowContrasted)
        roundedBackgroundView.apply(style: .cellWithoutHighlighting)
        contentInsets = .init(top: 9, left: 16, bottom: 9, right: 16)
        isUserInteractionEnabled = false
        preferredHeight = 52
    }

    func bind(viewModel: Model) {
        rowContentView.titleView.bind(viewModel: viewModel.vote)
        rowContentView.valueView.bind(viewModel: viewModel.amount)
    }
}
