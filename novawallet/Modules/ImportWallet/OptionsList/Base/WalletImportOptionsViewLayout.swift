import UIKit

class WalletImportOptionsViewLayout: ScrollableContainerLayoutView {
    enum Constants {
        static let itemSpacing: CGFloat = 12
    }

    let titleLabel: UILabel = .create { label in
        label.apply(style: .title3Primary)
        label.numberOfLines = 0
    }

    var rows: [UIStackView] = []

    override func setupStyle() {
        backgroundColor = R.color.colorSecondaryScreenBackground()
    }

    func apply(viewModel: WalletImportOptionViewModel) {
        rows.forEach { $0.removeFromSuperview() }

        rows = viewModel.rows.map { rowItems in
            let stackView = UIStackView()
            stackView.spacing = Constants.itemSpacing
            stackView.distribution = .fillEqually

            for item in rowItems {
                switch item {
                case let .primary(primary):
                    let view = WalletImportOptionPrimaryView()
                    stackView.addArrangedSubview(view)

                    view.bind(viewModel: primary)
                case let .secondary(secondary):
                    let view = WalletImportOptionSecondaryView()
                    stackView.addArrangedSubview(view)

                    view.bind(viewModel: secondary)
                }
            }

            return stackView
        }

        for rowView in rows {
            addArrangedSubview(rowView, spacingAfter: Constants.itemSpacing)
        }
    }

    override func setupLayout() {
        super.setupLayout()

        addArrangedSubview(titleLabel, spacingAfter: 20)
    }
}
