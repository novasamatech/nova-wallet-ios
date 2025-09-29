import UIKit

final class AssetListNetworkView: UICollectionReusableView {
    let chainView = AssetListChainView()

    let valueLabel: DotsSecureView<UILabel> = .create { view in
        view.preferredSecuredHeight = 18
        view.originalView.textColor = R.color.colorTextSecondary()
        view.originalView.font = .regularFootnote
        view.originalView.textAlignment = .right
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: AssetListNetworkGroupViewModel) {
        switch viewModel.amount.originalContent {
        case let .loaded(value), let .cached(value):
            valueLabel.originalView.text = value
        case .loading:
            valueLabel.originalView.text = ""
        }

        chainView.nameLabel.text = viewModel.networkName

        let networkViewModel = NetworkViewModel(
            name: viewModel.networkName,
            icon: viewModel.icon
        )

        chainView.bind(viewModel: networkViewModel)
        valueLabel.bind(viewModel.amount.privacyMode)
    }

    private func setupLayout() {
        addSubview(chainView)
        chainView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(28.0)
            make.top.equalToSuperview().inset(13.0)
            make.bottom.equalToSuperview().inset(8.0)
        }

        addSubview(valueLabel)
        valueLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(32.0)
            make.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(chainView.snp.trailing).offset(8.0)
        }
    }
}
