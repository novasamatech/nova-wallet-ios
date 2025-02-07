import UIKit

final class WalletImportOptionSecondaryView: RowView<IconDetailsView> {
    var imageView: UIImageView {
        rowContentView.imageView
    }

    var titleLabel: UILabel {
        rowContentView.detailsLabel
    }

    private var onAction: WalletImportOptionViewModel.RowItem.ActionClosure?

    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupStyle()

        addTarget(self, action: #selector(actionTap), for: .touchUpInside)
    }

    private func setupStyle() {
        contentInsets = UIEdgeInsets(top: 14, left: 12, bottom: 14, right: 12)

        roundedBackgroundView.applyFilledBackgroundStyle()
        roundedBackgroundView.fillColor = R.color.colorButtonBackgroundSecondary()!
        roundedBackgroundView.highlightedFillColor = R.color.colorCellBackgroundPressed()!
        roundedBackgroundView.cornerRadius = 12
        roundedBackgroundView.roundingCorners = .allCorners

        rowContentView.mode = .iconDetails
        rowContentView.stackView.axis = .horizontal
        rowContentView.spacing = 12
        rowContentView.iconWidth = 24

        titleLabel.apply(style: .semiboldSubhedlinePrimary)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let contentFrame = rowContentView.frame

        let height = max(bounds.height - contentInsets.top - contentInsets.bottom, 0)

        rowContentView.frame = CGRect(
            origin: contentFrame.origin,
            size: CGSize(width: contentFrame.size.width, height: height)
        )
    }

    func bind(viewModel: WalletImportOptionViewModel.RowItem.Secondary) {
        imageView.image = viewModel.image
        titleLabel.text = viewModel.title

        onAction = viewModel.onAction
    }

    @objc func actionTap() {
        onAction?()
    }
}
