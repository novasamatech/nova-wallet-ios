import UIKit

class StackTableCell: RowView<GenericTitleValueView<UILabel, IconDetailsView>> {
    var titleLabel: UILabel { rowContentView.titleView }

    var detailsLabel: UILabel { rowContentView.valueView.detailsLabel }

    var iconImageView: UIImageView { rowContentView.valueView.imageView }

    private var imageViewModel: ImageViewModelProtocol?

    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configureStyle()
    }

    func bind(viewModel: StackCellViewModel?) {
        bind(details: viewModel?.details, imageViewModel: viewModel?.imageViewModel)
    }

    func bind(details: String) {
        bind(details: details, imageViewModel: nil)
    }

    private func bind(details: String?, imageViewModel: ImageViewModelProtocol?) {
        self.imageViewModel?.cancel(on: iconImageView)

        self.imageViewModel = imageViewModel

        detailsLabel.text = details
        iconImageView.image = nil

        let imageSize = rowContentView.valueView.iconWidth
        imageViewModel?.loadImage(
            on: iconImageView,
            targetSize: CGSize(width: imageSize, height: imageSize),
            cornerRadius: imageSize / 2.0,
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

        titleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        valueView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        valueView.detailsLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }
}

extension StackTableCell: StackTableViewCellProtocol {}
