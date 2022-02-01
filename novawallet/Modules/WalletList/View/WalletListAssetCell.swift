import UIKit

final class WalletListAssetCell: UICollectionViewCell {
    let iconView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .center
        return view
    }()

    let assetLabel: UILabel = {
        let label = UILabel()
        label.font = .semiBoldBody
        label.textColor = R.color.colorWhite()
        return label
    }()

    let priceLabel: UILabel = {
        let label = UILabel()
        label.font = .regularFootnote
        label.textColor = R.color.colorTransparentText()
        return label
    }()

    let priceChangeLabel: UILabel = {
        let label = UILabel()
        label.font = .regularFootnote
        label.textColor = R.color.colorTransparentText()
        return label
    }()

    let balanceLabel: UILabel = {
        let label = UILabel()
        label.font = .semiBoldBody
        label.textColor = R.color.colorWhite()
        label.textAlignment = .right
        return label
    }()

    let balanceValueLabel: UILabel = {
        let label = UILabel()
        label.font = .regularFootnote
        label.textColor = R.color.colorTransparentText()
        label.textAlignment = .right
        return label
    }()

    private var viewModel: WalletListViewModel?

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: WalletListViewModel) {
        self.viewModel?.icon?.cancel(on: iconView)

        self.viewModel = viewModel

        iconView.image = nil
        viewModel.icon?.loadImage(on: iconView, targetSize: CGSize(width: 28.0, height: 28.0), animated: true)

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
        contentView.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(28.0)
            make.top.bottom.equalToSuperview().inset(8.0)
            make.size.equalTo(40.0)
        }

        contentView.addSubview(assetLabel)
        assetLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(12.0)
            make.top.equalToSuperview().inset(8.0)
        }

        contentView.addSubview(priceLabel)
        priceLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(12.0)
            make.bottom.equalToSuperview().inset(8.0)
        }

        contentView.addSubview(priceChangeLabel)
        priceChangeLabel.snp.makeConstraints { make in
            make.leading.equalTo(priceLabel.snp.trailing).offset(4.0)
            make.bottom.equalToSuperview().inset(8.0)
        }

        contentView.addSubview(balanceLabel)
        balanceLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(32.0)
            make.leading.greaterThanOrEqualTo(assetLabel.snp.trailing).offset(4.0)
            make.top.equalToSuperview().inset(8.0)
        }

        contentView.addSubview(balanceValueLabel)
        balanceValueLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(32.0)
            make.leading.greaterThanOrEqualTo(priceChangeLabel.snp.trailing).offset(4.0)
            make.bottom.equalToSuperview().inset(8.0)
        }
    }
}
