import UIKit

final class GenericLedgerAccountStackCell: RowView<GenericTitleValueView<LoadableIconDetailsView, UIImageView>> {
    var titleLabel: UILabel { rowContentView.titleView.detailsLabel }
    var indicatorView: UIImageView { rowContentView.valueView }

    convenience init() {
        self.init(frame: CGRect(origin: .zero, size: CGSize(width: 340, height: 52.0)))
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        configure()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        titleLabel.apply(style: .regularSubhedlinePrimary)

        rowContentView.titleView.mode = .iconDetails
        rowContentView.titleView.spacing = 8.0
        rowContentView.titleView.iconWidth = 36.0

        indicatorView.image = R.image.iconSmallArrow()?.tinted(with: R.color.colorIconSecondary()!)
    }

    func bind(viewModel: StackCellViewModel) {
        rowContentView.titleView.bind(viewModel: viewModel)
    }
}

extension GenericLedgerAccountStackCell: StackTableViewCellProtocol {}
