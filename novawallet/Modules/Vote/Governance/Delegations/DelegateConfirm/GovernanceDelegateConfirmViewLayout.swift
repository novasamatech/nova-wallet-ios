import UIKit

final class GovernanceDelegateConfirmViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 0.0, left: 16.0, bottom: 0.0, right: 16.0)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        return view
    }()

    let amountView = MultilineBalanceView()

    let senderTableView = StackTableView()

    let walletCell = StackTableCell()

    let accountCell: StackInfoTableCell = {
        let cell = StackInfoTableCell()
        cell.detailsLabel.lineBreakMode = .byTruncatingMiddle
        return cell
    }()

    let feeCell = StackNetworkFeeCell()

    let delegateTableView = StackTableView()

    let delegateCell = GovernanceDelegateStackCell()

    private(set) var tracksCell: StackTableViewCellProtocol?

    let yourDelegationCell = StackTitleMultiValueCell()

    let changesTableView = StackTableView()

    var transferableTitleLabel: UILabel {
        transferableCell.rowContentView.titleView.detailsLabel
    }

    var transferableCell: StackTitleValueDiffCell = .create { cell in
        cell.rowContentView.titleView.imageView.image = R.image.iconGovTransferable()
    }

    var lockAmountTitleLabel: UILabel {
        lockedAmountCell.rowContentView.titleView.detailsLabel
    }

    let lockedAmountCell: StackTitleValueDiffCell = .create { cell in
        cell.rowContentView.titleView.imageView.image = R.image.iconGovAmountLock()
    }

    var undelegatingPeriodTitleLabel: UILabel {
        undelegatingPeriodCell.rowContentView.titleView.detailsLabel
    }

    let undelegatingPeriodCell: StackIconTitleValueCell = .create {
        $0.iconView.image = R.image.iconGovPeriodLock()
    }

    let hintsView = HintListView()

    let actionLoadableView = LoadableActionView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func clearTrackCell() {
        tracksCell?.removeFromSuperview()
        tracksCell = nil

        delegateTableView.updateLayout()
    }

    func addTracksCell(for title: String, viewModel: GovernanceTracksViewModel) -> StackInfoTableCell? {
        clearTrackCell()

        if viewModel.canExpand {
            let cell = StackInfoTableCell()
            cell.titleLabel.text = title
            cell.bind(details: viewModel.details)
            tracksCell = cell
        } else {
            let cell = StackTableCell()
            cell.titleLabel.text = title
            cell.bind(details: viewModel.details)
            tracksCell = cell
        }

        if let tracksCell = tracksCell {
            delegateTableView.insertArranged(view: tracksCell, after: delegateCell)
        }

        return tracksCell as? StackInfoTableCell
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

        containerView.stackView.addArrangedSubview(amountView)
        containerView.stackView.setCustomSpacing(20.0, after: amountView)

        containerView.stackView.addArrangedSubview(senderTableView)
        containerView.stackView.setCustomSpacing(12.0, after: senderTableView)

        senderTableView.addArrangedSubview(walletCell)
        senderTableView.addArrangedSubview(accountCell)
        senderTableView.addArrangedSubview(feeCell)

        containerView.stackView.addArrangedSubview(delegateTableView)
        containerView.stackView.setCustomSpacing(12.0, after: delegateTableView)

        delegateTableView.addArrangedSubview(delegateCell)
        delegateTableView.addArrangedSubview(yourDelegationCell)

        containerView.stackView.addArrangedSubview(changesTableView)

        changesTableView.addArrangedSubview(transferableCell)
        changesTableView.addArrangedSubview(lockedAmountCell)
        changesTableView.addArrangedSubview(undelegatingPeriodCell)

        containerView.stackView.setCustomSpacing(16.0, after: changesTableView)

        containerView.stackView.addArrangedSubview(hintsView)
    }
}
