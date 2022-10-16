import UIKit

final class ReferendumVotersTableViewCell: UITableViewCell {
    typealias ContentView = GenericTitleValueView<IconDetailsGenericView<IconDetailsView>, MultiValueView>

    let baseView = ContentView()

    var iconView: UIImageView {
        baseView.titleView.imageView
    }

    var nameLabel: UILabel {
        baseView.titleView.detailsView.detailsLabel
    }

    var indicatorView: UIImageView {
        baseView.titleView.detailsView.imageView
    }

    var votesLabel: UILabel {
        baseView.valueView.valueTop
    }

    var detailsLabel: UILabel {
        baseView.valueView.valueBottom
    }

    private var iconViewModel: ImageViewModelProtocol?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        setupLayout()
        applyStyle()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: ReferendumVotersViewModel) {
        iconViewModel?.cancel(on: iconView)
        iconViewModel = viewModel.displayAddress.imageViewModel

        let imageSize = CGSize(width: baseView.titleView.iconWidth, height: baseView.titleView.iconWidth)
        iconViewModel?.loadImage(on: iconView, targetSize: imageSize, animated: true)

        let cellViewModel = viewModel.displayAddress.cellViewModel
        nameLabel.text = cellViewModel.details
        nameLabel.lineBreakMode = viewModel.displayAddress.lineBreakMode

        votesLabel.text = viewModel.votes
        detailsLabel.text = viewModel.preConviction

        setNeedsLayout()
    }

    private func applyStyle() {
        backgroundColor = .clear

        baseView.spacing = 32.0
        baseView.titleView.mode = .iconDetails
        baseView.titleView.iconWidth = 24.0
        baseView.titleView.spacing = 12.0

        baseView.titleView.detailsView.spacing = 4.0
        baseView.titleView.detailsView.iconWidth = 16.0
        baseView.titleView.detailsView.mode = .detailsIcon

        baseView.valueView.stackView.alignment = .fill

        nameLabel.numberOfLines = 1
        nameLabel.apply(style: UILabel.Style(textColor: R.color.colorWhite()!, font: .regularFootnote))
        indicatorView.image = R.image.iconInfoFilled()?.tinted(with: R.color.colorWhite48()!)

        votesLabel.apply(style: UILabel.Style(textColor: R.color.colorWhite()!, font: .regularFootnote))
        detailsLabel.apply(style: UILabel.Style(textColor: R.color.colorTransparentText()!, font: .caption1))

        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = R.color.colorAccentSelected()
        self.selectedBackgroundView = selectedBackgroundView
    }

    private func setupLayout() {
        contentView.addSubview(baseView)

        baseView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.bottom.equalToSuperview()
        }
    }
}
