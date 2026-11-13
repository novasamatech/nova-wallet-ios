import UIKit
import UIKit_iOS

final class SwapTokenSelectTokenCell: UITableViewCell {
    let currentBackgroundView: UIView = .create { view in
        view.backgroundColor = R.color.colorCellBackgroundPressed()
    }

    let accentView: RoundedView = .create { view in
        view.shadowOpacity = 0
        view.fillColor = R.color.colorIndicatorActive()!
        view.highlightedFillColor = R.color.colorIndicatorActive()!
        view.cornerRadius = Constants.accentCornerRadius
        view.roundingCorners = [.topRight, .bottomRight]
    }

    let tokenIconView: AssetIconView = .create { view in
        view.backgroundView.cornerRadius = Constants.iconContainerSize / 2
        view.backgroundView.strokeWidth = Constants.iconBorderWidth
        view.contentInsets = UIEdgeInsets(
            top: Constants.iconInset,
            left: Constants.iconInset,
            bottom: Constants.iconInset,
            right: Constants.iconInset
        )
    }

    let networkIconView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFit
        view.layer.cornerRadius = Constants.badgeCornerRadius
        view.clipsToBounds = true
    }

    let symbolLabel: UILabel = .create { view in
        view.apply(style: .semiboldBodyPrimary)
    }

    let networkLabel: UILabel = .create { view in
        view.apply(style: .footnoteSecondary)
    }

    let amountLabel: UILabel = .create { view in
        view.apply(style: .semiboldBodyPrimary)
        view.textAlignment = .right
    }

    let priceLabel: UILabel = .create { view in
        view.apply(style: .footnoteSecondary)
        view.textAlignment = .right
    }

    let activityIndicator: UIActivityIndicatorView = .create { view in
        view.style = .medium
        view.color = R.color.colorIconPrimary()
        view.hidesWhenStopped = true
    }

    private var networkIconViewModel: ImageViewModelProtocol?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear

        let selectedView = UIView()
        selectedView.backgroundColor = R.color.colorCellBackgroundPressed()
        selectedBackgroundView = selectedView

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        networkIconViewModel?.cancel(on: networkIconView)
        networkIconViewModel = nil
        networkIconView.image = nil
    }

    func bind(viewModel: SwapTokenSelectTokenViewModel) {
        let iconSize = CGSize(width: Constants.iconSize, height: Constants.iconSize)
        tokenIconView.bind(viewModel: viewModel.tokenIcon, size: iconSize)

        networkIconViewModel?.cancel(on: networkIconView)
        networkIconViewModel = viewModel.networkIcon
        networkIconView.image = nil

        viewModel.networkIcon?.loadImage(
            on: networkIconView,
            targetSize: CGSize(width: Constants.badgeSize, height: Constants.badgeSize),
            animated: false
        )

        symbolLabel.text = viewModel.symbol
        networkLabel.text = viewModel.networkName

        amountLabel.text = viewModel.balance?.amount
        priceLabel.text = viewModel.balance?.price

        currentBackgroundView.isHidden = !viewModel.isCurrent && !viewModel.isPending
        accentView.isHidden = !viewModel.isCurrent

        bind(isPending: viewModel.isPending)
    }
}

// MARK: Private

private extension SwapTokenSelectTokenCell {
    func bind(isPending: Bool) {
        amountLabel.isHidden = isPending
        priceLabel.isHidden = isPending

        if isPending {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
    }

    func setupLayout() {
        contentView.addSubview(currentBackgroundView)
        currentBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentView.addSubview(accentView)
        accentView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.equalToSuperview().inset(Constants.accentTopInset)
            make.width.equalTo(Constants.accentWidth)
            make.height.equalTo(Constants.accentHeight)
        }

        contentView.addSubview(tokenIconView)
        tokenIconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalToSuperview().inset(Constants.verticalInset)
            make.size.equalTo(Constants.iconContainerSize)
        }

        contentView.addSubview(networkIconView)
        networkIconView.snp.makeConstraints { make in
            make.leading.equalTo(tokenIconView).offset(Constants.badgeOffset)
            make.top.equalTo(tokenIconView).offset(Constants.badgeOffset)
            make.size.equalTo(Constants.badgeSize)
        }

        setupLabelsLayout()
    }

    func setupLabelsLayout() {
        contentView.addSubview(amountLabel)
        amountLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalToSuperview().inset(Constants.verticalInset)
        }

        contentView.addSubview(priceLabel)
        priceLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(amountLabel.snp.bottom)
        }

        contentView.addSubview(symbolLabel)
        symbolLabel.snp.makeConstraints { make in
            make.leading.equalTo(tokenIconView.snp.trailing).offset(Constants.labelsLeadingOffset)
            make.top.equalToSuperview().inset(Constants.verticalInset)
            make.trailing.lessThanOrEqualTo(amountLabel.snp.leading).offset(-Constants.labelsSpacing)
        }

        contentView.addSubview(networkLabel)
        networkLabel.snp.makeConstraints { make in
            make.leading.equalTo(symbolLabel)
            make.top.equalTo(symbolLabel.snp.bottom)
            make.trailing.lessThanOrEqualTo(priceLabel.snp.leading).offset(-Constants.labelsSpacing)
        }

        amountLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        priceLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        contentView.addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
        }
    }
}

// MARK: Constants

extension SwapTokenSelectTokenCell {
    enum Constants {
        static let height: CGFloat = 56
        static let verticalInset: CGFloat = 8
        static let iconContainerSize: CGFloat = 42
        static let iconInset: CGFloat = 1
        static let iconSize: CGFloat = 40
        static let iconBorderWidth: CGFloat = 1
        static let badgeSize: CGFloat = 16
        static let badgeOffset: CGFloat = 27
        static let badgeCornerRadius: CGFloat = 5
        static let labelsLeadingOffset: CGFloat = 10
        static let labelsSpacing: CGFloat = 8
        static let accentWidth: CGFloat = 3
        static let accentHeight: CGFloat = 40
        static let accentTopInset: CGFloat = 8
        static let accentCornerRadius: CGFloat = 2
    }
}
