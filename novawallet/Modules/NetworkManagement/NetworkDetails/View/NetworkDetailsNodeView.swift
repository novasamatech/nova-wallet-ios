import UIKit_iOS
import UIKit

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
        contentDisplayView.roundedContainerView.backgroundView.sendSubviewToBack(separatorView)
        separatorView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.top.equalToSuperview().inset(separatorView.strokeWidth)
        }
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        contentDisplayView.roundedContainerView.backgroundView.isHighlighted = highlighted
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
    var viewModel: NetworkDetailsViewLayout.NodeModel?

    var roundedContainerView = GenericBorderedView<
        GenericPairValueView<
            GenericPairValueView<
                UIImageView,
                GenericMultiValueView<
                    GenericMultiValueView<
                        GenericPairValueView<UIImageView, ShimmerLabel>
                    >
                >
            >,
            GenericPairValueView<UIImageView, UILabel>
        >
    >()

    var selectionImageView: UIImageView {
        roundedContainerView.contentView.fView.fView
    }

    var nameLabel: UILabel {
        roundedContainerView.contentView.fView.sView.valueTop
    }

    var urlLabel: UILabel {
        roundedContainerView.contentView.fView.sView.valueBottom.valueTop
    }

    var networkStatusIcon: UIImageView {
        roundedContainerView.contentView.fView.sView.valueBottom.valueBottom.fView
    }

    var networkStatusLabel: ShimmerLabel {
        roundedContainerView.contentView.fView.sView.valueBottom.valueBottom.sView
    }

    var networkStatusView: GenericPairValueView<UIImageView, ShimmerLabel> {
        roundedContainerView.contentView.fView.sView.valueBottom.valueBottom
    }

    var accessoryIcon: UIImageView {
        roundedContainerView.contentView.sView.fView
    }

    var editLabel: UILabel {
        roundedContainerView.contentView.sView.sView
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupActions()
        setupStyle()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: NetworkDetailsViewLayout.NodeModel) {
        self.viewModel = viewModel

        if viewModel.selected {
            selectionImageView.image = R.image.iconRadioButtonSelected()
        } else {
            selectionImageView.image = R.image.iconRadioButtonUnselected()
        }

        switch viewModel.accessory {
        case let .edit(text):
            accessoryIcon.isHidden = true
            editLabel.isHidden = false
            editLabel.text = text
        case .more:
            accessoryIcon.image = R.image.iconMore()
            accessoryIcon.isHidden = false
            editLabel.isHidden = true
        case .none:
            accessoryIcon.isHidden = true
            editLabel.isHidden = true
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

        updateNetworkStatus(with: viewModel)
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

        roundedContainerView.contentView.fView.makeHorizontal()
        roundedContainerView.contentView.fView.stackView.alignment = .center
        roundedContainerView.contentInsets = Constants.contentInsets

        roundedContainerView.contentView.fView.spacing = Constants.roundedContainerSpacing

        selectionImageView.snp.makeConstraints { make in
            make.width.height.equalTo(Constants.selectionImageHeight)
        }

        roundedContainerView.contentView.fView.sView.stackView.alignment = .leading
        roundedContainerView.contentView.fView.sView.spacing = Constants.stackSpacing

        roundedContainerView.contentView.fView.sView.valueBottom.spacing = Constants.stackSpacing
        roundedContainerView.contentView.fView.sView.valueBottom.stackView.alignment = .leading

        roundedContainerView.contentView.sView.makeHorizontal()

        networkStatusView.makeHorizontal()
        networkStatusView.spacing = Constants.stackSpacing

        networkStatusIcon.snp.makeConstraints { make in
            make.width.height.equalTo(12)
        }

        accessoryIcon.snp.makeConstraints { make in
            make.width.height.equalTo(24)
        }
    }

    func setupStyle() {
        nameLabel.apply(style: .footnotePrimary)
        urlLabel.apply(style: .caption1Secondary)

        roundedContainerView.backgroundView.fillColor = R.color.colorBlockBackground()!
        roundedContainerView.backgroundView.highlightedFillColor = R.color.colorCellBackgroundPressed()!
        roundedContainerView.backgroundView.cornerRadius = Constants.cornerRadius

        networkStatusLabel.apply(style: .semiboldCaps2Primary)

        editLabel.apply(style: .regularSubhedlineAccent)
    }

    func setupActions() {
        let moreTapGesture = UITapGestureRecognizer(
            target: self,
            action: #selector(actionMore)
        )

        let editTapGesture = UITapGestureRecognizer(
            target: self,
            action: #selector(actionEdit)
        )

        editLabel.addGestureRecognizer(editTapGesture)
        editLabel.isUserInteractionEnabled = true

        accessoryIcon.addGestureRecognizer(moreTapGesture)
        accessoryIcon.isUserInteractionEnabled = true
    }

    func updateNetworkStatus(with viewModel: NetworkDetailsViewLayout.NodeModel) {
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
        case let .unknown(string):
            networkStatusLabel.stopShimmering()
            networkStatusLabel.apply(style: .semiboldCaps2Secondary)
            networkStatusLabel.text = string
            networkStatusIcon.image = R.image.iconConnectionStatusConnecting()
        }
    }

    @objc func actionMore() {
        guard
            let viewModel,
            case .more = viewModel.accessory
        else {
            return
        }

        viewModel.onTapMore?(viewModel.id)
    }

    @objc func actionEdit() {
        guard
            let viewModel,
            case .edit = viewModel.accessory
        else {
            return
        }

        viewModel.onTapEdit?(viewModel.id)
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
