import UIKit

final class SelectValidatorsConfirmViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 8.0, left: 16.0, bottom: 0.0, right: 16.0)
        view.stackView.alignment = .fill
        return view
    }()

    var stackView: UIStackView { containerView.stackView }

    let amountView = MultilineBalanceView()

    let walletTableView = StackTableView()

    let walletCell = StackTableCell()

    let accountCell: StackInfoTableCell = {
        let cell = StackInfoTableCell()
        cell.detailsLabel.lineBreakMode = .byTruncatingMiddle
        return cell
    }()

    let networkFeeCell = StackNetworkFeeCell()

    let rewardDestinationTableView = StackTableView()

    let rewardDestinationCell = StackTableCell()

    private(set) var payoutAccountCell: StackInfoTableCell?

    let validatorsTableView = StackTableView()

    let validatorsCell = StackTableCell()

    let actionButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    let hintListView = HintListView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func addPayoutAccountIfNeeded() {
        guard payoutAccountCell == nil else {
            return
        }

        let cell = StackInfoTableCell()
        cell.detailsLabel.lineBreakMode = .byTruncatingMiddle
        payoutAccountCell = cell

        rewardDestinationTableView.addArrangedSubview(cell)
    }

    func removePayoutAccountIfNeeded() {
        payoutAccountCell?.removeFromSuperview()
        payoutAccountCell = nil

        rewardDestinationTableView.updateLayout()
    }

    func addAmountIfNeeded() {
        amountView.isHidden = false
    }

    func removeAmountIfNeeded() {
        amountView.isHidden = true
    }

    func addRewardDestinationIfNeeded() {
        rewardDestinationTableView.isHidden = false
    }

    func removeRewardDestinationIfNeeded() {
        rewardDestinationTableView.isHidden = true
    }

    func bindHints(_ hints: [String]) {
        if hints.count > 1 {
            stackView.setCustomSpacing(24.0, after: validatorsTableView)
        } else {
            stackView.setCustomSpacing(12.0, after: validatorsTableView)
        }

        hintListView.bind(texts: hints)
    }

    private func setupLayout() {
        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(actionButton.snp.top).offset(-8.0)
        }

        stackView.addArrangedSubview(amountView)
        stackView.setCustomSpacing(24.0, after: amountView)

        stackView.addArrangedSubview(walletTableView)

        walletTableView.addArrangedSubview(walletCell)
        walletTableView.addArrangedSubview(accountCell)
        walletTableView.addArrangedSubview(networkFeeCell)

        stackView.setCustomSpacing(12.0, after: walletTableView)

        stackView.addArrangedSubview(rewardDestinationTableView)
        rewardDestinationTableView.addArrangedSubview(rewardDestinationCell)
        stackView.setCustomSpacing(12, after: rewardDestinationTableView)

        stackView.addArrangedSubview(validatorsTableView)
        validatorsTableView.addArrangedSubview(validatorsCell)
        stackView.setCustomSpacing(24.0, after: validatorsTableView)

        stackView.addArrangedSubview(hintListView)
    }
}
