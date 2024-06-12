import SoraUI

class NetworkDetailsNodeTableViewCell: PlainBaseTableViewCell<NetworkDetailsNodeView>, TableViewCellPositioning {
    let separatorView: BorderedContainerView = .create { view in
        view.strokeWidth = 0.5
        view.strokeColor = R.color.colorDivider()!
        view.borderType = .bottom
    }

    override func setupStyle() {
        super.setupStyle()

        backgroundColor = .clear
        selectionStyle = .none
    }

    override func setupLayout() {
        super.setupLayout()

        contentDisplayView.roundedContainerView.backgroundView.addSubview(separatorView)
        separatorView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.top.equalToSuperview().inset(separatorView.strokeWidth)
        }
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)

        contentDisplayView.roundedContainerView.backgroundView.fillColor = highlighted
            ? R.color.colorCellBackgroundPressed()!
            : R.color.colorBlockBackground()!
    }

    func apply(position: TableViewCellPosition) {
        switch position {
        case .single:
            contentDisplayView.roundedContainerView.backgroundView.roundingCorners = .allCorners
            separatorView.borderType = .none
        case .top:
            contentDisplayView.roundedContainerView.backgroundView.roundingCorners = [.topLeft, .topRight]
            separatorView.borderType = .bottom
        case .middle:
            contentDisplayView.roundedContainerView.backgroundView.roundingCorners = []
            separatorView.borderType = .bottom
        case .bottom:
            contentDisplayView.roundedContainerView.backgroundView.roundingCorners = [.bottomLeft, .bottomRight]
            separatorView.borderType = .none
        }
    }

    func bind(viewModel: NetworkDetailsViewLayout.NodeModel) {
        if viewModel.dimmed || viewModel.connectionState == .disconnected {
            isUserInteractionEnabled = false
        } else {
            isUserInteractionEnabled = true
        }

        contentDisplayView.bind(viewModel: viewModel)
    }
}

final class NetworkDetailsNodeView: UIView {
    var roundedContainerView = GenericBorderedView<
        GenericPairValueView<
            UIImageView,
            GenericMultiValueView<
                GenericMultiValueView<
                    GenericPairValueView<UIImageView, ShimmerLabel>
                >
            >
        >
    >()

    var selectionImageView: UIImageView {
        roundedContainerView.contentView.fView
    }

    var nameLabel: UILabel {
        roundedContainerView.contentView.sView.valueTop
    }

    var urlLabel: UILabel {
        roundedContainerView.contentView.sView.valueBottom.valueTop
    }

    var networkStatusIcon: UIImageView {
        roundedContainerView.contentView.sView.valueBottom.valueBottom.fView
    }

    var networkStatusLabel: ShimmerLabel {
        roundedContainerView.contentView.sView.valueBottom.valueBottom.sView
    }

    var networkStatusView: GenericPairValueView<UIImageView, ShimmerLabel> {
        roundedContainerView.contentView.sView.valueBottom.valueBottom
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupStyle()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: NetworkDetailsViewLayout.NodeModel) {
        if viewModel.selected {
            selectionImageView.image = R.image.iconRadioButtonSelected()
        } else {
            selectionImageView.image = R.image.iconRadioButtonUnselected()
        }

        nameLabel.text = viewModel.name
        urlLabel.text = viewModel.url

        if viewModel.dimmed || viewModel.connectionState == .disconnected {
            nameLabel.apply(style: .footnoteSecondary)
            selectionImageView.startShimmeringOpacity()
        } else {
            nameLabel.apply(style: .footnotePrimary)
            selectionImageView.stopShimmeringOpacity()
        }

        switch viewModel.connectionState {
        case let .connecting(string):
            networkStatusLabel.text = string
            networkStatusIcon.image = R.image.iconConnectionStatusConnecting()

            networkStatusLabel.applyShimmer(style: .semiboldCaps2Secondary)
            networkStatusLabel.startShimmering()
        case let .pinged(ping):
            networkStatusLabel.stopShimmering()

            switch ping {
            case let .low(text):
                networkStatusLabel.text = text
                networkStatusLabel.textColor = R.color.colorTextPositive()
                networkStatusIcon.image = R.image.iconConnectionStatusPerfect()
            case let .medium(text):
                networkStatusLabel.text = text
                networkStatusLabel.textColor = R.color.colorTextWarning()
                networkStatusIcon.image = R.image.iconConnectionStatusGood()
            case let .high(text):
                networkStatusLabel.text = text
                networkStatusLabel.textColor = R.color.colorTextNegative()
                networkStatusIcon.image = R.image.iconConnectionStatusBad()
            }
        case .disconnected:
            networkStatusLabel.text = nil
            networkStatusIcon.image = R.image.iconConnectionStatusConnecting()
        default:
            break
        }
    }
}

private extension NetworkDetailsNodeView {
    func setupLayout() {
        addSubview(roundedContainerView)
        roundedContainerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        roundedContainerView.contentView.makeHorizontal()
        roundedContainerView.contentView.stackView.alignment = .center
        roundedContainerView.contentInsets = Constants.contentInsets

        roundedContainerView.contentView.spacing = Constants.roundedContainerSpacing

        selectionImageView.snp.makeConstraints { make in
            make.width.height.equalTo(Constants.selectionImageHeight)
        }

        roundedContainerView.contentView.sView.stackView.alignment = .leading
        roundedContainerView.contentView.sView.spacing = Constants.stackSpacing

        roundedContainerView.contentView.sView.valueBottom.spacing = Constants.stackSpacing
        roundedContainerView.contentView.sView.valueBottom.stackView.alignment = .leading

        networkStatusView.makeHorizontal()
        networkStatusView.spacing = Constants.stackSpacing

        networkStatusIcon.snp.makeConstraints { make in
            make.width.height.equalTo(12)
        }

        setNeedsLayout()
    }

    func setupStyle() {
        nameLabel.apply(style: .footnotePrimary)
        urlLabel.apply(style: .caption1Secondary)

        roundedContainerView.backgroundView.fillColor = R.color.colorBlockBackground()!
        roundedContainerView.backgroundView.cornerRadius = Constants.cornerRadius

        networkStatusLabel.apply(style: .semiboldCaps2Primary)
    }
}

private extension NetworkDetailsNodeView {
    enum Constants {
        static let stackSpacing: CGFloat = 6.0
        static let roundedContainerSpacing: CGFloat = 16.5
        static let cornerRadius: CGFloat = 10.0
        static let selectionImageHeight: CGFloat = 20.0
        static let contentInsets = UIEdgeInsets(
            top: 9.5,
            left: UIConstants.horizontalInset,
            bottom: 9.5,
            right: UIConstants.horizontalInset
        )
    }
}
