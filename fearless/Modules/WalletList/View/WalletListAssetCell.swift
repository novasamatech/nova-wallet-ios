import UIKit

final class WalletListAssetCell: UITableViewCell {
    let backgroundBlurView: TriangularedBlurView = {
        let view = TriangularedBlurView()
        view.blurStyle = .dark
        view.overlayView.fillColor = .clear
        view.overlayView.highlightedFillColor = .clear
        view.cornerCut = .allCorners
        return view
    }()

    let iconView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .center
        return view
    }()

    let separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = R.color.colorBlurSeparator()
        return view
    }()

    let networkLabel: UILabel = {
        let label = UILabel()
        label.font = .capsTitle
        label.textColor = R.color.colorTransparentText()
        return label
    }()

    let assetLabel: UILabel = {
        let label = UILabel()
        label.font = .h3Title
        label.textColor = R.color.colorWhite()
        return label
    }()

    let priceLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorTransparentText()
        return label
    }()

    let priceChangeLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorTransparentText()
        return label
    }()

    let balanceLabel: UILabel = {
        let label = UILabel()
        label.font = .h3Title
        label.textColor = R.color.colorWhite()
        label.textAlignment = .right
        return label
    }()

    let balanceValueLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorTransparentText()
        label.textAlignment = .right
        return label
    }()

    private var viewModel: WalletListViewModel?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        selectedBackgroundView = UIView()

        setupLayout()
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        viewModel?.icon?.cancel(on: iconView)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: WalletListViewModel) {
        self.viewModel?.icon?.cancel(on: iconView)

        self.viewModel = viewModel

        iconView.image = nil
        viewModel.icon?.loadImage(on: iconView, targetSize: CGSize(width: 48.0, height: 48.0), animated: true)

        networkLabel.text = viewModel.networkName
        assetLabel.text = viewModel.tokenName

        applyPrice(viewModel.price)
        applyBalance(viewModel.balanceAmount)
        applyBalanceValue(viewModel.balanceValue)
    }

    private func applyPrice(_ priceViewModel: LoadableViewModelState<WalletPriceViewModel>) {
        switch priceViewModel {
        case .loading:
            priceLabel.text = ""
            priceChangeLabel.text = ""
        case let .cached(value):
            priceLabel.text = value.amount
            applyPriceChange(value.change)
        case let .loaded(value):
            priceLabel.text = value.amount
            applyPriceChange(value.change)
        }
    }

    private func applyPriceChange(_ priceChangeViewModel: ValueDirection<String>) {
        switch priceChangeViewModel {
        case let .increase(value):
            priceChangeLabel.text = value
            priceChangeLabel.textColor = R.color.colorGreen()
        case let .decrease(value):
            priceChangeLabel.text = value
            priceChangeLabel.textColor = R.color.colorRed()
        }
    }

    private func applyBalance(_ balanceViewModel: LoadableViewModelState<String>) {
        switch balanceViewModel {
        case .loading:
            balanceLabel.text = ""
        case let .cached(value):
            balanceLabel.text = value
        case let .loaded(value):
            balanceLabel.text = value
        }
    }

    private func applyBalanceValue(_ balanceValueViewModel: LoadableViewModelState<String>) {
        switch balanceValueViewModel {
        case .loading:
            balanceValueLabel.text = ""
        case let .cached(value):
            balanceValueLabel.text = value
        case let .loaded(value):
            balanceValueLabel.text = value
        }
    }

    private func setupLayout() {
        contentView.addSubview(backgroundBlurView)
        backgroundBlurView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalToSuperview()
            make.bottom.equalToSuperview().inset(8.0)
        }

        contentView.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.leading.top.bottom.equalTo(backgroundBlurView)
            make.width.equalTo(63.0)
        }

        contentView.addSubview(separatorView)
        separatorView.snp.makeConstraints { make in
            make.top.bottom.equalTo(backgroundBlurView).inset(8.0)
            make.leading.equalTo(iconView.snp.trailing)
            make.width.equalTo(1 / UIScreen.main.scale)
        }

        contentView.addSubview(networkLabel)
        networkLabel.snp.makeConstraints { make in
            make.leading.equalTo(separatorView).offset(8.0)
            make.top.equalTo(backgroundBlurView).offset(8.0)
        }

        contentView.addSubview(assetLabel)
        assetLabel.snp.makeConstraints { make in
            make.leading.equalTo(separatorView).offset(8.0)
            make.top.equalTo(backgroundBlurView).offset(26.0)
        }

        contentView.addSubview(priceLabel)
        priceLabel.snp.makeConstraints { make in
            make.leading.equalTo(separatorView).offset(8.0)
            make.bottom.equalTo(backgroundBlurView).offset(-10.0)
        }

        contentView.addSubview(priceChangeLabel)
        priceChangeLabel.snp.makeConstraints { make in
            make.leading.equalTo(priceLabel.snp.trailing).offset(4.0)
            make.bottom.equalTo(backgroundBlurView).offset(-10.0)
        }

        contentView.addSubview(balanceLabel)
        balanceLabel.snp.makeConstraints { make in
            make.trailing.equalTo(backgroundBlurView).offset(-12.0)
            make.leading.greaterThanOrEqualTo(assetLabel.snp.trailing).offset(4.0)
            make.top.equalTo(backgroundBlurView).offset(26.0)
        }

        contentView.addSubview(balanceValueLabel)
        balanceValueLabel.snp.makeConstraints { make in
            make.trailing.equalTo(backgroundBlurView).offset(-12.0)
            make.leading.greaterThanOrEqualTo(priceChangeLabel.snp.trailing).offset(4.0)
            make.bottom.equalTo(backgroundBlurView).offset(-10.0)
        }
    }
}
