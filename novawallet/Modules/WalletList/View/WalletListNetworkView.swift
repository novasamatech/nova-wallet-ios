import UIKit

final class WalletListNetworkView: UICollectionReusableView {
    let chainView = WalletChainView()

    let valueLabel: UILabel = {
        let view = UILabel()
        view.textColor = R.color.colorTransparentText()
        view.font = .regularFootnote
        view.textAlignment = .right
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        setupLayout()
    }

    var iconViewModel: ImageViewModelProtocol?

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: WalletListGroupViewModel) {
        iconViewModel?.cancel(on: chainView.iconView)
        chainView.iconView.image = nil

        switch viewModel.amount {
        case let .loaded(value), let .cached(value):
            valueLabel.text = value
        case .loading:
            valueLabel.text = ""
        }

        chainView.nameLabel.text = viewModel.networkName

        iconViewModel = viewModel.icon
        iconViewModel?.loadImage(
            on: chainView.iconView,
            targetSize: CGSize(width: 21.0, height: 21.0),
            animated: true
        )
    }

    private func setupLayout() {
        addSubview(chainView)
        chainView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(32.0)
            make.top.bottom.equalToSuperview().inset(8.0)
        }

        addSubview(valueLabel)
        valueLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(32.0)
            make.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(chainView.snp.trailing).offset(8.0)
        }
    }
}
