import UIKit

final class YourVoteRow: RowView<GenericTitleValueView<YourVoteView, MultiValueView>> {
    struct Model {
        let vote: YourVoteView.Model
        let amount: MultiValueView.Model
    }

    let voteView: YourVoteView = .create {
        $0.apply(style: .ayeInverse)
    }

    let amountView: MultiValueView = .create {
        $0.apply(style: .rowContrasted)
    }

    lazy var contentMultiValueView = GenericTitleValueView<YourVoteView, MultiValueView>(
        titleView: voteView,
        valueView: amountView
    )

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView = contentMultiValueView
        backgroundView = TriangularedBlurView()
        contentInsets = .init(top: 9, left: 16, bottom: 9, right: 16)
        preferredHeight = 52
        backgroundColor = .clear
    }

    func bind(viewModel: Model) {
        voteView.bind(viewModel: viewModel.vote)
        amountView.bind(viewModel: viewModel.amount)
    }
}
