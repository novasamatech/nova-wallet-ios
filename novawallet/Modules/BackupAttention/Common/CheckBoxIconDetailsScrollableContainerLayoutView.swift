import UIKit

final class CheckBoxIconDetailsScrollableView: ScrollableContainerLayoutView {
    var checkBoxViews: [CheckBoxIconDetailsView] = [
        .init(frame: .zero),
        .init(frame: .zero),
        .init(frame: .zero)
    ]

    var titleView = BackupAttentionTableTitleView()

    override func setupLayout() {
        super.setupLayout()

        addArrangedSubview(titleView, spacingAfter: 12)

        checkBoxViews.forEach { addArrangedSubview($0, spacingAfter: 12) }
    }

    func bind(viewModel: Model) {
        checkBoxViews
            .enumerated()
            .forEach { $0.element.bind(viewModel: viewModel.rows[$0.offset]) }

        setNeedsLayout()
    }
}

// MARK: Model

extension CheckBoxIconDetailsScrollableView {
    struct Model {
        let rows: [CheckBoxIconDetailsView.Model]
    }
}
