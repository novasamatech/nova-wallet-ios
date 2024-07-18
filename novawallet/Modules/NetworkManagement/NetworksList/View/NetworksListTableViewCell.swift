import UIKit

final class NetworksListTableViewCell: PlainBaseTableViewCell<NetworksListNetworkView> {
    override func setupStyle() {
        super.setupStyle()

        backgroundColor = .clear
    }
}

final class NetworksListNetworkView: UIView {
    private enum Constants {
        static let networkIconSize: CGFloat = 36.0
        static let addressIconSize: CGFloat = 16.0
        static let horizontalInsets: CGFloat = 12.0
        static let networkTypeCornerRadius: CGFloat = 6.0
        static let networkTypeContentInsets: UIEdgeInsets = .init(
            top: 1.5,
            left: 6,
            bottom: 1.5,
            right: 6
        )
    }

    let networkIconView: UIImageView = {
        let view = UIImageView()
        return view
    }()

    let networkLabelsPairView: GenericPairValueView<
        GenericPairValueView<
            UILabel,
            GenericBorderedView<UILabel>
        >,
        UILabel
    > = .create { view in
        view.fView.makeHorizontal()
        view.fView.fView.apply(style: .regularSubhedlinePrimary)
        view.fView.fView.textAlignment = .left

        view.fView.sView.contentView.apply(style: .semiboldCaps2Secondary)
        view.fView.sView.backgroundView.fillColor = R.color.colorChipsBackground()!
        view.fView.sView.contentInsets = Constants.networkTypeContentInsets
        view.fView.sView.backgroundView.cornerRadius = Constants.networkTypeCornerRadius

        view.fView.sView.isHidden = true

        view.fView.spacing = 8

        view.sView.apply(style: .footnotePrimary)
        view.sView.textAlignment = .left
        view.sView.numberOfLines = 0
        view.sView.isHidden = true

        view.spacing = 4
    }

    var networkLabel: UILabel { networkLabelsPairView.fView.fView }
    var networkTypeView: GenericBorderedView<UILabel> { networkLabelsPairView.fView.sView }
    var secondaryLabel: UILabel { networkLabelsPairView.sView }

    let connectionStateLabel: ShimmerLabel = .create { view in
        view.applyShimmer(style: .caption2Secondary)
    }

    let actionIconView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFit

        view.image = R.image.iconSmallArrow()?.tinted(
            with: R.color.colorTextTertiary()!
        )
    }

    private var viewModel: NetworksListViewLayout.NetworkWithConnectionModel?

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(with viewModel: NetworksListViewLayout.NetworkWithConnectionModel) {
        self.viewModel?.networkModel.network.icon?.cancel(on: networkIconView)
        self.viewModel = viewModel

        networkLabel.text = viewModel.networkModel.network.name

        if let networkType = viewModel.networkType {
            networkTypeView.contentView.text = networkType
            networkTypeView.isHidden = false
        } else {
            networkTypeView.isHidden = true
        }

        switch viewModel.networkState {
        case .enabled:
            secondaryLabel.isHidden = true
            networkLabel.apply(style: .regularSubhedlinePrimary)
            networkIconView.stopShimmeringOpacity()
        case let .disabled(text):
            secondaryLabel.isHidden = false
            networkLabel.apply(style: .regularSubhedlineInactive)
            secondaryLabel.apply(style: .regularSubhedlineInactive)
            secondaryLabel.text = text
            networkIconView.startShimmeringOpacity()
        }

        viewModel.networkModel.network.icon?.loadImage(
            on: networkIconView,
            targetSize: CGSize(
                width: Constants.networkIconSize,
                height: Constants.networkIconSize
            ),
            animated: true
        )

        switch viewModel.connectionState {
        case let .connecting(text):
            actionIconView.isHidden = true
            connectionStateLabel.isHidden = false
            connectionStateLabel.text = text
            connectionStateLabel.startShimmering()
        case .connected, .notConnected:
            actionIconView.isHidden = false
            connectionStateLabel.stopShimmering()
            connectionStateLabel.isHidden = true
            connectionStateLabel.text = nil
        }

        setNeedsLayout()
    }

    private func setupLayout() {
        addSubview(networkIconView)
        networkIconView.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.size.equalTo(Constants.networkIconSize)
        }

        addSubview(actionIconView)
        actionIconView.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
        }

        addSubview(connectionStateLabel)
        connectionStateLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalTo(actionIconView.snp.leading).offset(-Constants.horizontalInsets)
        }

        addSubview(networkLabelsPairView)
        networkLabelsPairView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(networkIconView.snp.trailing).offset(Constants.horizontalInsets)
            make.trailing.lessThanOrEqualTo(connectionStateLabel.snp.leading).offset(-Constants.horizontalInsets)
        }
    }
}
