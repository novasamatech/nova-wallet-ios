import UIKit

final class RequestedAmountRow: RowView<GenericMultiValueView<MultiValueView>> {
    struct Model {
        let title: String
        let amount: MultiValueView.Model
    }

    var titleLabel: UILabel { rowContentView.valueTop }

    let amountView: MultiValueView = .create {
        $0.apply(style: .accentAmount)
        $0.valueTop.textAlignment = .left
        $0.valueBottom.textAlignment = .left
    }

    lazy var contentMultiValueView = GenericMultiValueView<MultiValueView>(valueBottom: amountView)

    override init(frame: CGRect) {
        super.init(frame: frame)

        setup()
    }

    private func setup() {
        contentView = contentMultiValueView
        preferredHeight = 102
        rowContentView.spacing = 2
        rowContentView.valueBottom.spacing = 2
        titleLabel.apply(style: .footnoteWhite64)
        titleLabel.textAlignment = .left
        backgroundView = TriangularedBlurView()
        contentInsets = .init(top: 16, left: 16, bottom: 16, right: 16)
        backgroundColor = .clear
    }

    func bind(viewModel: Model) {
        titleLabel.text = viewModel.title
        amountView.bind(viewModel: viewModel.amount)
    }
}
