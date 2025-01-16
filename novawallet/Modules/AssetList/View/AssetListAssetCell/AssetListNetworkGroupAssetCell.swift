import UIKit_iOS
import UIKit

final class AssetListNetworkGroupAssetCell: AssetListAssetCell {
    let priceLabel: UILabel = {
        let label = UILabel()
        label.font = .regularFootnote
        label.textColor = R.color.colorTextSecondary()
        return label
    }()

    let priceChangeLabel: UILabel = {
        let label = UILabel()
        label.font = .regularFootnote
        label.textColor = .clear
        return label
    }()

    override func createDetailsView() -> UIView {
        let containerView = UIView()

        containerView.addSubview(priceLabel)
        priceLabel.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
        }

        containerView.addSubview(priceChangeLabel)
        priceChangeLabel.snp.makeConstraints { make in
            make.leading.equalTo(priceLabel.snp.trailing).offset(4.0)
            make.bottom.top.trailing.equalToSuperview()
        }

        return containerView
    }

    func bind(viewModel: AssetListNetworkGroupAssetViewModel) {
        bind(
            viewModel: viewModel,
            balanceKeyPath: \.balance,
            imageKeyPath: \.icon,
            nameKeyPath: \.tokenName
        )

        selectedView.cornerRadius = 0
    }

    override func bind<T>(
        viewModel: T,
        balanceKeyPath: KeyPath<T, AssetListAssetBalanceViewModel>,
        imageKeyPath: KeyPath<T, (any ImageViewModelProtocol)?>,
        nameKeyPath: KeyPath<T, String>
    ) {
        super.bind(
            viewModel: viewModel,
            balanceKeyPath: balanceKeyPath,
            imageKeyPath: imageKeyPath,
            nameKeyPath: nameKeyPath
        )

        let priceViewModel = viewModel[keyPath: balanceKeyPath].price

        applyPrice(priceViewModel)
    }

    private func applyPrice(_ priceViewModel: LoadableViewModelState<AssetPriceViewModel>) {
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
            priceChangeLabel.textColor = R.color.colorTextPositive()
        case let .decrease(value):
            priceChangeLabel.text = value
            priceChangeLabel.textColor = R.color.colorTextNegative()
        }
    }
}
