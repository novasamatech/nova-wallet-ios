import UIKit
import UIKit_iOS

final class SubtensorConfirmViewLayout: UIView {
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

    let validatorsTableView: StackTableView = .create {
        $0.cellHeight = 44
        $0.hasSeparators = true
        $0.contentInsets = UIEdgeInsets(top: 0, left: 16, bottom: 4, right: 16)
        $0.isHidden = true
    }

    let validatorsHeaderCell = StackTableHeaderCell()

    private var legCells: [StackTitleMultiValueCell] = []

    let avgBuyPriceCell = SubtensorConfirmViewLayout.createCostBasisCell()

    let youWillEarnCell = SubtensorConfirmViewLayout.createCostBasisCell()

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
    }

    let stakingTypeCell = StackTableCell()

    let stakeAfterCell = StackTableCell()

    let rootValidatorCell = StackInfoTableCell()

    let apyCell: StackTableCell = .create {
        $0.detailsLabel.textColor = R.color.colorTextPositive()
    }

    let feeDisclosureLabel: UILabel = .create {
        $0.textAlignment = .center
        $0.apply(style: .caption1Secondary)
        $0.numberOfLines = 0
    }

    let remarkLabel: UILabel = .create {
        $0.apply(style: .caption1Secondary)
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
        case let .swap(direction):
            setupSwapContent(with: swapRows(for: direction))
        case .rootStake:
            setupRootContent(with: [stakingTypeCell, stakeAfterCell, rootValidatorCell, apyCell])
        case .rootUnstake:
            setupRootContent(with: [stakingTypeCell, rootValidatorCell, stakeAfterCell])
        }
    }
}

extension SubtensorConfirmViewLayout {
    func bind(breakdown: SubtensorConfirmBreakdownViewModel?) {
        guard breakdown != nil || !validatorsTableView.isHidden else {
            return
        }

        validatorsTableView.isHidden = breakdown == nil
        validatorCell.isHidden = breakdown != nil
        rootValidatorCell.isHidden = breakdown != nil
        detailsTableView.updateLayout()
        rootTableView.updateLayout()

        guard let breakdown else {
            return
        }

        validatorsHeaderCell.titleLabel.text = breakdown.title

        while legCells.count < breakdown.legs.count {
            let cell: StackTitleMultiValueCell = .create { $0.canSelect = false }
            legCells.append(cell)
            validatorsTableView.addArrangedSubview(cell)
        }

        legCells.enumerated().forEach { index, cell in
            cell.isHidden = index >= breakdown.legs.count

            guard index < breakdown.legs.count else {
                return
            }

            let leg = breakdown.legs[index]
            cell.titleLabel.text = leg.name
            cell.titleLabel.lineBreakMode = .byTruncatingTail
            cell.bind(viewModel: BalanceViewModel(amount: leg.amount, price: leg.detail))
        }

        validatorsTableView.updateLayout()
    }

    enum Mode {
        case swap(SubtensorTradeDirection)
        case rootStake
        case rootUnstake
    }
}

private extension SubtensorConfirmViewLayout {
    static func createCostBasisCell() -> SwapNetworkFeeViewCell {
        .create {
            $0.rowContentView.valueView.stackView.alignment = .trailing
            $0.valueTopButton.imageWithTitleView?.spacingBetweenLabelAndIcon = 3
        }
    }

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

    func swapRows(for direction: SubtensorTradeDirection) -> [StackTableViewCellProtocol] {
        switch direction {
        case .buy:
            return [swapRateCell, slippageCell, validatorCell, avgBuyPriceCell, networkFeeCell]
        case .sell:
            return [swapRateCell, avgBuyPriceCell, youWillEarnCell, slippageCell, validatorCell, networkFeeCell]
        }
    }

    func setupSwapContent(with rows: [StackTableViewCellProtocol]) {
        stackView.addArrangedSubview(priceMovedView)
        stackView.setCustomSpacing(8, after: priceMovedView)

        stackView.addArrangedSubview(pairsView)
        stackView.setCustomSpacing(8, after: pairsView)

        stackView.addArrangedSubview(detailsTableView)
        stackView.setCustomSpacing(8, after: detailsTableView)

        rows.forEach { detailsTableView.addArrangedSubview($0) }

        setupValidatorsTable()

        stackView.addArrangedSubview(walletTableView)
        stackView.setCustomSpacing(8, after: walletTableView)

        walletTableView.addArrangedSubview(walletCell)
        walletTableView.addArrangedSubview(accountCell)

        stackView.addArrangedSubview(remarkLabel)
        stackView.setCustomSpacing(8, after: remarkLabel)
        stackView.addArrangedSubview(feeDisclosureLabel)
    }

    func setupRootContent(with rows: [StackTableViewCellProtocol]) {
        stackView.layoutMargins.top = 24
        stackView.addArrangedSubview(amountView)
        stackView.setCustomSpacing(32, after: amountView)

        stackView.addArrangedSubview(walletTableView)
        stackView.setCustomSpacing(8, after: walletTableView)

        walletTableView.contentInsets.bottom = 0
        walletTableView.addArrangedSubview(walletCell)
        walletTableView.addArrangedSubview(accountCell)
        walletTableView.addArrangedSubview(rootFeeCell)

        stackView.addArrangedSubview(rootTableView)
        stackView.setCustomSpacing(8, after: rootTableView)

        rows.forEach { rootTableView.addArrangedSubview($0) }

        setupValidatorsTable()
    }

    func setupValidatorsTable() {
        stackView.addArrangedSubview(validatorsTableView)
        stackView.setCustomSpacing(8, after: validatorsTableView)

        validatorsTableView.addArrangedSubview(validatorsHeaderCell)
    }
}
