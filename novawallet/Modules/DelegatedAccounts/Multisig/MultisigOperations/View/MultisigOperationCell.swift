import UIKit
import SnapKit
import UIKit_iOS

typealias MultisigOperationCell = BlurredCollectionViewCell<MultisigOperationView>

final class MultisigOperationView: UIView {
    let operationTypeValues: MultiValueView = .create { view in
        view.valueTop.apply(style: .regularSubhedlinePrimary)
        view.valueTop.textAlignment = .left

        view.valueBottom.apply(style: .footnoteSecondary)
        view.valueBottom.textAlignment = .left
    }

    let amountTimeValues: MultiValueView = .create { view in
        view.valueTop.apply(style: .regularSubhedlinePrimary)
        view.valueTop.textAlignment = .right

        view.valueBottom.apply(style: .footnoteSecondary)
        view.valueBottom.textAlignment = .right
    }

    let delegatedAccountView: GenericBackgroundView<
        GenericPairValueView<
            UILabel,
            IconDetailsView
        >
    > = .create { view in
        view.wrappedView.makeHorizontal()
        view.wrappedView.stackView.distribution = .fillEqually
        view.wrappedView.stackView.alignment = .center
        view.fillColor = R.color.colorBlockBackground()!

        view.wrappedView.fView.textAlignment = .left
        view.wrappedView.fView.apply(style: .caption1Secondary)

        view.wrappedView.sView.spacing = 4.0
        view.wrappedView.sView.detailsLabel.apply(style: .caption1Secondary)
        view.wrappedView.sView.iconWidth = Constants.addressIconSize
        view.wrappedView.sView.detailsLabel.numberOfLines = 1
        view.wrappedView.sView.detailsLabel.lineBreakMode = .byTruncatingMiddle

        view.cornerRadius = .zero
        view.roundingCorners = [.bottomLeft, .bottomRight]
        view.cornerRadius = Constants.cornerRadius
        view.contentInsets = Constants.delegatedViewContentInsets
    }

    let borderedContainer: BorderedContainerView = .create { view in
        view.borderType = [.top]
        view.strokeWidth = 2.0
        view.strokeColor = R.color.colorDivider()!
        view.fillColor = .clear
    }

    let operationIconView: AssetIconView = .create { view in
        view.backgroundView.cornerRadius = Constants.iconSize / 2.0
        view.backgroundView.fillColor = R.color.colorContainerBackground()!
        view.backgroundView.highlightedFillColor = R.color.colorContainerBackground()!
    }

    let statusView: IconDetailsView = .create { view in
        view.mode = .detailsIcon
        view.spacing = Constants.statusViewInnerSpacing
        view.iconWidth = Constants.statusIconSize
    }

    let networkIconView: UIImageView = {
        let view = UIImageView()
        return view
    }()

    var operationTypeLabel: UILabel {
        operationTypeValues.valueTop
    }

    var subtitleLabel: UILabel {
        operationTypeValues.valueBottom
    }

    var amountLabel: UILabel {
        amountTimeValues.valueTop
    }

    var timeLabel: UILabel {
        amountTimeValues.valueBottom
    }

    let signingProgressLabel: UILabel = .create { view in
        view.apply(style: .semiboldCaps1ChipText)
    }

    var statusLabel: UILabel {
        statusView.detailsLabel
    }

    var statusIcon: UIImageView {
        statusView.imageView
    }

    var delegatedAccountFieldLabel: UILabel {
        delegatedAccountView.wrappedView.fView
    }

    var delegatedAccountIconView: UIImageView {
        delegatedAccountView.wrappedView.sView.imageView
    }

    var delegatedAccountDetailsLabel: UILabel {
        delegatedAccountView.wrappedView.sView.detailsLabel
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Private

private extension MultisigOperationView {
    func setupLayout() {
        addSubview(signingProgressLabel)
        signingProgressLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(Constants.contentInsets.left)
            make.top.equalToSuperview().inset(Constants.contentInsets.top)
        }

        addSubview(statusView)
        statusView.snp.makeConstraints { make in
            make.centerY.equalTo(signingProgressLabel)
            make.trailing.equalToSuperview().inset(Constants.contentInsets.right)
        }

        addSubview(operationIconView)
        operationIconView.snp.makeConstraints { make in
            make.size.equalTo(Constants.iconSize)
            make.leading.equalTo(signingProgressLabel)
            make.top.equalTo(signingProgressLabel.snp.bottom).offset(Constants.iconTopOffset)
            make.bottom.equalToSuperview().inset(Constants.contentInsets.bottom)
        }

        addSubview(networkIconView)
        networkIconView.snp.makeConstraints { make in
            make.size.equalTo(Constants.networkIconSize)
            make.trailing.bottom.equalTo(operationIconView).offset(Constants.networkIconOffset)
        }

        addSubview(operationTypeValues)
        operationTypeValues.snp.makeConstraints { make in
            make.centerY.equalTo(operationIconView)
            make.leading.equalTo(operationIconView.snp.trailing).offset(Constants.typeValuesLeadingOffset)
            make.top.bottom.equalTo(operationIconView)
        }

        addSubview(amountTimeValues)
        amountTimeValues.snp.makeConstraints { make in
            make.centerY.equalTo(operationTypeValues)
            make.trailing.equalTo(statusView)
        }
    }

    func updateOperationIcon(with viewModel: ImageViewModelProtocol) {
        let settings = ImageViewModelSettings(
            targetSize: CGSize(width: Constants.iconSize, height: Constants.iconSize),
            cornerRadius: nil,
            tintColor: R.color.colorIconSecondary()
        )

        operationIconView.bind(viewModel: viewModel, settings: settings)
    }

    func updateStatus(with status: MultisigOperationViewModel.Status?) {
        guard let status else {
            statusView.isHidden = true
            return
        }

        statusView.isHidden = false

        switch status {
        case let .createdByUser(text):
            statusView.hidesIcon = true
            statusLabel.apply(style: .caption1Secondary)
            statusLabel.text = text
        case let .signed(model):
            statusView.hidesIcon = false
            statusView.bind(viewModel: model)
            statusLabel.apply(style: .caption1Positive)
        }
    }

    func updateSubtitle(with subtitle: String?) {
        if let subtitle {
            subtitleLabel.text = subtitle
            subtitleLabel.isHidden = false
        } else {
            subtitleLabel.isHidden = true
        }
    }

    func updateAmount(with amount: String?) {
        if let amount {
            amountLabel.text = amount
            amountLabel.isHidden = false
        } else {
            amountLabel.isHidden = true
        }
    }

    func updateDelegatedAccountView(delegatedAccountModel: MultisigOperationViewModel.DelegatedAccount?) {
        if let delegatedAccountModel {
            delegatedAccountFieldLabel.text = delegatedAccountModel.title
            delegatedAccountDetailsLabel.lineBreakMode = delegatedAccountModel.model.lineBreakMode
            delegatedAccountDetailsLabel.text = delegatedAccountModel.model.name
                ?? delegatedAccountModel.model.address

            delegatedAccountModel.model.imageViewModel?.loadImage(
                on: delegatedAccountIconView,
                targetSize: CGSize(width: Constants.addressIconSize, height: Constants.addressIconSize),
                animated: true
            )

            updateConstraints(showingFooter: true)
        } else {
            updateConstraints(showingFooter: false)
        }
    }

    func updateConstraints(showingFooter: Bool) {
        borderedContainer.removeFromSuperview()
        delegatedAccountView.removeFromSuperview()

        if showingFooter {
            borderedContainer.addSubview(delegatedAccountView)
            delegatedAccountView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }

            addSubview(borderedContainer)
            borderedContainer.snp.makeConstraints { make in
                make.leading.trailing.bottom.equalToSuperview()
                make.height.equalTo(Constants.delegatedAccountViewHeight)
            }

            operationIconView.snp.remakeConstraints { make in
                make.size.equalTo(Constants.iconSize)
                make.leading.equalTo(signingProgressLabel)
                make.top.equalTo(signingProgressLabel.snp.bottom).offset(Constants.iconTopOffset)
                make.bottom.equalTo(borderedContainer.snp.top).offset(-Constants.iconBottomOffsetToFooter)
            }
        } else {
            operationIconView.snp.remakeConstraints { make in
                make.size.equalTo(Constants.iconSize)
                make.leading.equalTo(signingProgressLabel)
                make.top.equalTo(signingProgressLabel.snp.bottom).offset(Constants.iconTopOffset)
                make.bottom.equalToSuperview().inset(Constants.contentInsets.bottom)
            }
        }
    }
}

// MARK: - Internal

extension MultisigOperationView {
    func bind(viewModel: MultisigOperationViewModel) {
        viewModel.chainIcon.network.icon?.loadImage(
            on: networkIconView,
            targetSize: CGSize(width: Constants.networkIconSize, height: Constants.networkIconSize),
            animated: true
        )
        updateOperationIcon(with: viewModel.iconViewModel)

        signingProgressLabel.text = viewModel.signingProgress
        operationTypeLabel.text = viewModel.operationTitle

        updateStatus(with: viewModel.status)
        updateSubtitle(with: viewModel.operationSubtitle)
        updateAmount(with: viewModel.amount)

        timeLabel.text = viewModel.timeString

        updateDelegatedAccountView(delegatedAccountModel: viewModel.delegatedAccountModel)
    }
}

// MARK: - Constants

private extension MultisigOperationView {
    enum Constants {
        static let iconSize: CGFloat = 32.0
        static let networkIconSize: CGFloat = 16.0
        static let addressIconSize: CGFloat = 16.0
        static let statusIconSize: CGFloat = 16.0

        static let iconTopOffset: CGFloat = 14.5
        static let iconBottomOffsetToFooter: CGFloat = 16.0
        static let networkIconOffset: CGFloat = 3.0

        static let typeValuesLeadingOffset: CGFloat = 12.0

        static let delegatedAccountViewHeight: CGFloat = 40.0

        static let cornerRadius: CGFloat = 12.0
        static let contentInsets = UIEdgeInsets(top: 13.5, left: 12.0, bottom: 20.0, right: 12.0)

        static let delegatedViewContentInsets = UIEdgeInsets(top: 10.0, left: 12.0, bottom: 6.0, right: 12.0)

        static let statusViewInnerSpacing: CGFloat = 4.0
    }
}
