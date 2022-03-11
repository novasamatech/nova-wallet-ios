import UIKit

class StackInfoTableCell: RowView<GenericTitleValueView<UILabel, IconDetailsGenericView<IconDetailsView>>> {
    var titleLabel: UILabel { rowContentView.titleView }

    var detailsLabel: UILabel { rowContentView.valueView.detailsView.detailsLabel }

    var iconImageView: UIImageView { rowContentView.valueView.imageView }

    private var viewModel: StackCellViewModel?

    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configureStyle()
    }

    func bind(viewModel: StackCellViewModel?) {
        self.viewModel?.imageViewModel?.cancel(on: iconImageView)

        self.viewModel = viewModel

        detailsLabel.text = viewModel?.details
        iconImageView.image = nil

        let imageSize = rowContentView.valueView.iconWidth
        viewModel?.imageViewModel?.loadImage(
            on: iconImageView,
            targetSize: CGSize(width: imageSize, height: imageSize),
            animated: true
        )
    }

    private func configureStyle() {
        titleLabel.textColor = R.color.colorTransparentText()
        titleLabel.font = .regularFootnote

        let valueView = rowContentView.valueView
        valueView.mode = .iconDetails
        detailsLabel.textColor = R.color.colorWhite()
        detailsLabel.font = .regularFootnote
        detailsLabel.numberOfLines = 1
        valueView.spacing = 8.0
        valueView.iconWidth = 20.0

        let accessoryView = rowContentView.valueView.detailsView
        accessoryView.mode = .detailsIcon
        accessoryView.iconWidth = 16.0
        accessoryView.spacing = 8.0
        accessoryView.imageView.image = R.image.iconInfoFilled()?
            .withRenderingMode(.alwaysTemplate)
            .tinted(with: R.color.colorTransparentText()!)

        preferredHeight = 44.0
        borderView.strokeColor = R.color.colorWhite8()!

        contentInsets = UIEdgeInsets(top: 0.0, left: 16.0, bottom: 0.0, right: 16.0)

        titleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        valueView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        valueView.detailsView.detailsLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }
}
