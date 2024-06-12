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
        contentDisplayView.bind(viewModel: viewModel)
    }
}

final class NetworkDetailsNodeView: UIView {
    var roundedContainerView = GenericBorderedView<
        GenericPairValueView<
            UIImageView,
            GenericMultiValueView<
                GenericMultiValueView<
                    ImageWithTitleView
                >
            >
        >
    >()

    var selectionImageView: UIImageView { roundedContainerView.contentView.fView }
    var nameLabel: UILabel { roundedContainerView.contentView.sView.valueTop }
    var urlLabel: UILabel { roundedContainerView.contentView.sView.valueBottom.valueTop }
    var networkStatusView: ImageWithTitleView { roundedContainerView.contentView.sView.valueBottom.valueBottom }

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

        switch viewModel.connectionState {
        case let .connecting(string):
            networkStatusView.title = string
            networkStatusView.iconImage = R.image.iconConnectionStatusConnecting()
        case let .pinged(ping):
            switch ping {
            case let .low(text):
                networkStatusView.title = text
                networkStatusView.iconImage = R.image.iconConnectionStatusBad()
            case let .medium(text):
                networkStatusView.title = text
                networkStatusView.iconImage = R.image.iconConnectionStatusGood()
            case let .high(text):
                networkStatusView.title = text
                networkStatusView.iconImage = R.image.iconConnectionStatusPerfect()
            }
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

        networkStatusView.spacingBetweenLabelAndIcon = Constants.stackSpacing
        networkStatusView.titleFont = .semiBoldCaps2

        setNeedsLayout()
    }

    func setupStyle() {
        nameLabel.apply(style: .footnoteSecondary)
        urlLabel.apply(style: .caption1Secondary)

        roundedContainerView.backgroundView.fillColor = R.color.colorBlockBackground()!
        roundedContainerView.backgroundView.cornerRadius = Constants.cornerRadius
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