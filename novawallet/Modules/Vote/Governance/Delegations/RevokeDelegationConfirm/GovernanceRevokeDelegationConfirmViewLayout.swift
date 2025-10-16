import UIKit

final class GovRevokeDelegationConfirmViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 16.0, left: 16.0, bottom: 0.0, right: 16.0)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        return view
    }()

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

    private(set) var yourDelegationCell: StackTitleMultiValueCell?

    let changesTableView = StackTableView()

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

    func addYourDelegationCell(for viewModel: GovernanceYourDelegationViewModel, locale: Locale) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.govYourDelegation()

        let cell = delegateTableView.addTitleMultiValue(
            for: title,
            valueTop: viewModel.votes,
            valueBottom: viewModel.conviction
        )

        cell.canSelect = false
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

        containerView.stackView.addArrangedSubview(senderTableView)
        containerView.stackView.setCustomSpacing(12.0, after: senderTableView)

        senderTableView.addArrangedSubview(walletCell)
        senderTableView.addArrangedSubview(accountCell)
        senderTableView.addArrangedSubview(feeCell)

        containerView.stackView.addArrangedSubview(delegateTableView)
        containerView.stackView.setCustomSpacing(12.0, after: delegateTableView)

        delegateTableView.addArrangedSubview(delegateCell)

        containerView.stackView.addArrangedSubview(changesTableView)

        changesTableView.addArrangedSubview(undelegatingPeriodCell)

        containerView.stackView.setCustomSpacing(16.0, after: changesTableView)

        containerView.stackView.addArrangedSubview(hintsView)
    }
}
