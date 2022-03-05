import UIKit

class StackTableCell: RowView<GenericTitleValueView<UILabel, IconDetailsView>> {
    var titleLabel: UILabel { rowContentView.titleView }

    var detailsLabel: UILabel { rowContentView.valueView.detailsLabel }

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

        preferredHeight = 44.0
        borderView.strokeColor = R.color.colorWhite8()!

        isUserInteractionEnabled = false
    }
}
