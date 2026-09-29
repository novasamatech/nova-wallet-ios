import UIKit
import UIKit_iOS

final class SubtensorStakingConfirmViewLayout: UIView {
    let containerView: ScrollableContainerView = .create {
        $0.stackView.isLayoutMarginsRelativeArrangement = true
        $0.stackView.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 16, right: 16)
        $0.stackView.alignment = .fill
    }

    var stackView: UIStackView { containerView.stackView }

    let priceMovedView: InlineAlertView = {
        let view = InlineAlertView.info()
        view.isHidden = true
        return view
    }()

    let pairsView: SwapPairView = .create {
        $0.leftAssetView.hidesHub = true
        $0.rigthAssetView.hidesHub = true
    }

    let detailsTableView: StackTableView = .create {
        $0.cellHeight = 44
        $0.hasSeparators = true
        $0.contentInsets = UIEdgeInsets(top: 0, left: 16, bottom: 4, right: 16)
    }

    let swapRateCell: SwapInfoViewCell = .create {
        $0.titleButton.imageWithTitleView?.titleColor = R.color.colorTextSecondary()
        $0.titleButton.imageWithTitleView?.titleFont = .regularFootnote
    }

    let slippageCell: SwapInfoViewCell = .create {
        $0.titleButton.imageWithTitleView?.titleColor = R.color.colorTextSecondary()
        $0.titleButton.imageWithTitleView?.titleFont = .regularFootnote
    }

    let validatorCell = SubtensorValidatorDetailsCell()

    let earnCell = SwapNetworkFeeViewCell()

    let networkFeeCell = SwapNetworkFeeViewCell()

    let amountView = MultilineBalanceView()

    let walletTableView: StackTableView = .create {
        $0.cellHeight = 44
        $0.hasSeparators = true
        $0.contentInsets = UIEdgeInsets(top: 0, left: 16, bottom: 8, right: 16)
    }

    let walletCell = StackTableCell()

    let accountCell: StackInfoTableCell = .create {
        $0.detailsLabel.lineBreakMode = .byTruncatingMiddle
    }

    let rootFeeCell = StackNetworkFeeCell()

    let rootTableView: StackTableView = .create {
        $0.cellHeight = 44
        $0.hasSeparators = true
        $0.contentInsets = UIEdgeInsets(top: 0, left: 16, bottom: 8, right: 16)
    }

    let stakingTypeCell = StackTableCell()

    let stakeAfterCell = StackTableCell()

    let rootValidatorCell = StackInfoTableCell()

    let apyCell: StackTableCell = .create {
        $0.detailsLabel.textColor = R.color.colorTextPositive()
    }

    let remarkLabel: UILabel = .create {
        $0.apply(style: .footnoteSecondary)
        $0.textAlignment = .center
        $0.numberOfLines = 0
    }

    let signingHintView: AccountManagementHintView = .create {
        $0.isHidden = true
    }

    let actionLoadableView = LoadableActionView()

    var actionButton: TriangularedButton {
        actionLoadableView.actionButton
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupMode(_ mode: Mode) {
        switch mode {
        case .swap:
            setupSwapContent()
        case .rootStake:
            setupRootContent(with: [stakingTypeCell, stakeAfterCell, rootValidatorCell, apyCell])
        case .rootUnstake:
            setupRootContent(with: [stakingTypeCell, rootValidatorCell, stakeAfterCell])
        }
    }
}

extension SubtensorStakingConfirmViewLayout {
    enum Mode {
        case swap
        case rootStake
        case rootUnstake
    }
}

private extension SubtensorStakingConfirmViewLayout {
    func setupLayout() {
        let bottomView = UIView.vStack(spacing: 16, [signingHintView, actionLoadableView])

        addSubview(bottomView)
        bottomView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
        }

        actionLoadableView.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
        }

        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(bottomView.snp.top).offset(-8)
        }
    }

    func setupSwapContent() {
        stackView.addArrangedSubview(priceMovedView)
        stackView.setCustomSpacing(8, after: priceMovedView)

        stackView.addArrangedSubview(pairsView)
        stackView.setCustomSpacing(8, after: pairsView)

        stackView.addArrangedSubview(detailsTableView)
        stackView.setCustomSpacing(8, after: detailsTableView)

        detailsTableView.addArrangedSubview(swapRateCell)
        detailsTableView.addArrangedSubview(slippageCell)
        detailsTableView.addArrangedSubview(validatorCell)
        detailsTableView.addArrangedSubview(earnCell)
        detailsTableView.addArrangedSubview(networkFeeCell)

        stackView.addArrangedSubview(walletTableView)
        stackView.setCustomSpacing(8, after: walletTableView)

        walletTableView.addArrangedSubview(walletCell)
        walletTableView.addArrangedSubview(accountCell)

        stackView.addArrangedSubview(remarkLabel)
    }

    func setupRootContent(with rows: [StackTableViewCellProtocol]) {
        stackView.addArrangedSubview(amountView)
        stackView.setCustomSpacing(24, after: amountView)

        stackView.addArrangedSubview(walletTableView)
        stackView.setCustomSpacing(8, after: walletTableView)

        walletTableView.addArrangedSubview(walletCell)
        walletTableView.addArrangedSubview(accountCell)
        walletTableView.addArrangedSubview(rootFeeCell)

        stackView.addArrangedSubview(rootTableView)

        rows.forEach { rootTableView.addArrangedSubview($0) }
    }
}
