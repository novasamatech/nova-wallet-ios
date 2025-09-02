import UIKit

final class CollatorStkUnstakeConfirmLayout: UIView {
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

    let collatorTableView = StackTableView()

    let collatorCell = StackInfoTableCell()

    let actionLoadableView = LoadableActionView()

    var actionButton: TriangularedButton {
        actionLoadableView.actionButton
    }

    let hintListView = HintListView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()

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

        stackView.addArrangedSubview(amountView)
        stackView.setCustomSpacing(24.0, after: amountView)

        stackView.addArrangedSubview(walletTableView)

        walletTableView.addArrangedSubview(walletCell)
        walletTableView.addArrangedSubview(accountCell)
        walletTableView.addArrangedSubview(networkFeeCell)

        stackView.setCustomSpacing(12.0, after: walletTableView)

        stackView.addArrangedSubview(collatorTableView)
        collatorTableView.addArrangedSubview(collatorCell)
        stackView.setCustomSpacing(24.0, after: collatorTableView)

        stackView.addArrangedSubview(hintListView)
    }
}
