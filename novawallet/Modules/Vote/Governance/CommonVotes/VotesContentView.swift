import UIKit

final class VotesContentView:
    GenericTitleValueView<IconDetailsGenericView<IconDetailsView>, MultiValueView> {
    enum Constants {
        static let titleValueSpacing: CGFloat = 32.0
        static let addressNameSpacing: CGFloat = 12.0
        static let addressIndicatorSpacing: CGFloat = 4.0
        static let iconSize = CGSize(width: 24.0, height: 24.0)
        static let indicatorSize = CGSize(width: 16.0, height: 16.0)
    }

    var iconView: UIImageView {
        titleView.imageView
    }

    var nameLabel: UILabel {
        titleView.detailsView.detailsLabel
    }

    var indicatorView: UIImageView {
        titleView.detailsView.imageView
    }

    var votesLabel: UILabel {
        valueView.valueTop
    }

    var detailsLabel: UILabel {
        valueView.valueBottom
    }

    private var iconViewModel: ImageViewModelProtocol?

    override init(frame: CGRect) {
        super.init(frame: frame)

        applyStyle()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: VotesViewModel) {
        iconViewModel?.cancel(on: iconView)
        iconViewModel = viewModel.displayAddress.imageViewModel

        let imageSize = CGSize(width: titleView.iconWidth, height: titleView.iconWidth)
        iconViewModel?.loadImage(on: iconView, targetSize: imageSize, animated: true)

        let cellViewModel = viewModel.displayAddress.cellViewModel
        nameLabel.text = cellViewModel.details
        nameLabel.lineBreakMode = viewModel.displayAddress.lineBreakMode

        votesLabel.text = viewModel.votes
        detailsLabel.text = viewModel.votesDetails

        setNeedsLayout()
    }

    private func applyStyle() {
        backgroundColor = .clear

        spacing = Constants.titleValueSpacing
        titleView.mode = .iconDetails
        titleView.iconWidth = Constants.iconSize.width
        titleView.spacing = Constants.addressNameSpacing

        titleView.detailsView.spacing = Constants.addressIndicatorSpacing
        titleView.detailsView.iconWidth = Constants.indicatorSize.width
        titleView.detailsView.mode = .detailsIcon

        valueView.stackView.alignment = .fill

        nameLabel.numberOfLines = 1
        nameLabel.apply(style: .footnotePrimary)
        indicatorView.image = R.image.iconInfoFilled()?.tinted(with: R.color.colorIconSecondary()!)

        votesLabel.apply(style: .footnotePrimary)
        detailsLabel.apply(style: .caption1Secondary)
    }
}
