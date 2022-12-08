import UIKit

final class TokensAddNetworkSelectionTableViewCell: UITableViewCell {
    let cellView: GenericTitleValueView<IconDetailsView, UIImageView> = .create { view in
        view.titleView.detailsLabel.numberOfLines = 1
        view.titleView.detailsLabel.apply(style: .regularSubhedlinePrimary)
        view.titleView.spacing = 12
        view.titleView.iconWidth = 24

        view.valueView.image = R.image.iconSmallArrow()?.tinted(with: R.color.colorIconSecondary()!)
    }

    var titleLabel: UILabel { cellView.titleView.detailsLabel }
    var iconView: UIImageView { cellView.titleView.imageView }
    var iconSize: CGSize {
        let iconWidth = cellView.titleView.iconWidth
        return CGSize(width: iconWidth, height: iconWidth)
    }

    private var imageViewModel: ImageViewModelProtocol?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = R.color.colorCellBackgroundPressed()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: NetworkViewModel) {
        imageViewModel?.cancel(on: iconView)
        imageViewModel = viewModel.icon

        iconView.image = nil
        imageViewModel?.loadImage(on: iconView, targetSize: iconSize, animated: true)

        titleLabel.text = viewModel.name
    }

    private func setupLayout() {
        contentView.addSubview(cellView)

        cellView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.top.equalToSuperview()
        }
    }
}
