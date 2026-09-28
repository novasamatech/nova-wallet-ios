import UIKit

final class SubtensorStakingConfirmViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 8.0, left: 16.0, bottom: 0.0, right: 16.0)
        view.stackView.alignment = .fill
        return view
    }()

    var stackView: UIStackView { containerView.stackView }

    let amountView = MultilineBalanceView()

    let swapPreview = UIStackView()
    let payCard = UIView()
    let receiveCard = UIView()
    let payAmountLabel = UILabel()
    let payPriceLabel = UILabel()
    let receiveAmountLabel = UILabel()
    let receivePriceLabel = UILabel()

    let walletTableView = StackTableView()

    let walletCell = StackTableCell()

    let accountCell: StackInfoTableCell = {
        let cell = StackInfoTableCell()
        cell.detailsLabel.lineBreakMode = .byTruncatingMiddle
        return cell
    }()

    let networkFeeCell = StackNetworkFeeCell()

    let quoteTableView = StackTableView()

    let receiveCell = StackTableCell()

    let poolFeeCell = StackTableCell()

    let priceImpactCell = StackTableCell()

    let slippageCell = StackTableCell()

    let collatorTableView = StackTableView()

    let collatorCell = StackInfoTableCell()
    let stakingTypeCell = StackTableCell()

    let actionLoadableView = LoadableActionView()

    var actionButton: TriangularedButton {
        actionLoadableView.actionButton
    }

    let hintListView = HintListView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()

        setupPreview()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(actionLoadableView)
        actionLoadableView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(actionLoadableView.snp.top).offset(-8.0)
        }

        stackView.addArrangedSubview(swapPreview)
        stackView.addArrangedSubview(amountView)
        stackView.setCustomSpacing(24.0, after: amountView)

        stackView.addArrangedSubview(walletTableView)

        walletTableView.addArrangedSubview(walletCell)
        walletTableView.addArrangedSubview(accountCell)
        walletTableView.addArrangedSubview(networkFeeCell)

        stackView.setCustomSpacing(12.0, after: walletTableView)

        stackView.addArrangedSubview(quoteTableView)

        quoteTableView.addArrangedSubview(receiveCell)
        quoteTableView.addArrangedSubview(poolFeeCell)
        quoteTableView.addArrangedSubview(priceImpactCell)
        quoteTableView.addArrangedSubview(slippageCell)

        stackView.setCustomSpacing(12.0, after: quoteTableView)

        stackView.addArrangedSubview(collatorTableView)
        collatorTableView.addArrangedSubview(stakingTypeCell)
        collatorTableView.addArrangedSubview(collatorCell)
        stackView.setCustomSpacing(24.0, after: collatorTableView)

        stackView.addArrangedSubview(hintListView)
    }

    func setRootMode(_ isRoot: Bool) {
        swapPreview.isHidden = isRoot
        amountView.isHidden = !isRoot
        stakingTypeCell.isHidden = !isRoot
        if isRoot {
            move(walletTableView, after: amountView)
            move(collatorTableView, after: walletTableView)
        } else {
            move(quoteTableView, after: swapPreview)
            move(collatorTableView, after: quoteTableView)
            move(walletTableView, after: collatorTableView)
        }
    }

    private func move(_ view: UIView, after previous: UIView) {
        stackView.removeArrangedSubview(view)
        view.removeFromSuperview()
        let index = (stackView.arrangedSubviews.firstIndex(of: previous) ?? 0) + 1
        stackView.insertArrangedSubview(view, at: index)
    }

    private func setupPreview() {
        swapPreview.axis = .horizontal
        swapPreview.distribution = .fillEqually
        swapPreview.spacing = 8
        [payCard, receiveCard].forEach { card in
            card.backgroundColor = R.color.colorBlockBackground()
            card.layer.cornerRadius = 12
            swapPreview.addArrangedSubview(card)
        }
        swapPreview.snp.makeConstraints { make in make.height.equalTo(134) }

        [payAmountLabel, receiveAmountLabel].forEach { label in
            label.font = .boldTitle2
            label.textColor = R.color.colorTextPrimary()
            label.textAlignment = .center
        }
        [payPriceLabel, receivePriceLabel].forEach { label in
            label.font = .regularFootnote
            label.textColor = R.color.colorTextSecondary()
            label.textAlignment = .center
        }
        let payStack = UIStackView.vStack(alignment: .center, spacing: 4, [payAmountLabel, payPriceLabel])
        let receiveStack = UIStackView.vStack(alignment: .center, spacing: 4, [receiveAmountLabel, receivePriceLabel])
        payCard.addSubview(payStack)
        receiveCard.addSubview(receiveStack)
        payStack.snp.makeConstraints { make in make.center.equalToSuperview(); make.leading.trailing.equalToSuperview().inset(8) }
        receiveStack.snp.makeConstraints { make in make.center.equalToSuperview(); make.leading.trailing.equalToSuperview().inset(8) }
    }
}
