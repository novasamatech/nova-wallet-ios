import UIKit

final class ReferendumDetailsViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 6.0, left: 16, bottom: 24, right: 16)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        return view
    }()

    let titleView = ReferendumDetailsTitleView()
    let votingDetailsRow = ReferendumVotingStatusDetailsView()
    let dAppsTableView: StackTableView = .create {
        $0.cellHeight = 64.0
        $0.contentInsets = UIEdgeInsets(top: 8.0, left: 16.0, bottom: 8.0, right: 16.0)
    }

    var timelineView = TimelineRow()

    var yourVoteRow: YourVoteRow?
    var requestedAmountRow: RequestedAmountRow?

    let fullDetailsView = FullDetailsRow(frame: .zero)

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(containerView)
        containerView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        containerView.stackView.spacing = 12
        containerView.stackView.addArrangedSubview(titleView)
        containerView.stackView.setCustomSpacing(16, after: titleView)

        containerView.stackView.addArrangedSubview(votingDetailsRow)
        containerView.stackView.addArrangedSubview(dAppsTableView)
        containerView.stackView.addArrangedSubview(timelineView)
        containerView.stackView.addArrangedSubview(fullDetailsView)

        dAppsTableView.apply(style: .cellWithoutHighlighting)
    }

    func setTimeline(model: [ReferendumTimelineView.Model]?, locale: Locale) {
        let title = R.string.localizable.govReferendumDetailsTimelineTitle(
            preferredLanguages: locale.rLanguages
        )

        timelineView.titleLabel.text = title

        timelineView.bindOrHide(viewModel: model)
    }

    func setDApps(models: [ReferendumDAppView.Model]?, locale: Locale) -> [ReferendumDAppCellView] {
        dAppsTableView.clear()

        if let models = models {
            dAppsTableView.isHidden = false

            let title = R.string.localizable.commonUseDapp(
                preferredLanguages: locale.rLanguages
            )

            let headerView = createHeader(with: title)
            dAppsTableView.setCustomHeight(32, at: 0)
            dAppsTableView.addArrangedSubview(headerView)

            let cells: [ReferendumDAppCellView] = models.map { model in
                let dAppView = ReferendumDAppCellView()
                dAppView.rowContentView.bind(viewModel: model)
                return dAppView
            }

            cells.forEach {
                dAppsTableView.addArrangedSubview($0)
            }

            return cells
        } else {
            dAppsTableView.isHidden = true

            return []
        }
    }

    func setYourVote(model: YourVoteRow.Model?) {
        guard let yourVoteViewModel = model else {
            yourVoteRow?.removeFromSuperview()
            yourVoteRow = nil
            return
        }

        if yourVoteRow == nil {
            let yourVoteView = YourVoteRow(frame: .zero)
            containerView.stackView.insertArranged(view: yourVoteView, before: votingDetailsRow)
            yourVoteRow = yourVoteView
        }

        yourVoteRow?.bind(viewModel: yourVoteViewModel)
    }

    func setRequestedAmount(model: RequestedAmountRow.Model?) {
        guard let requestedAmountViewModel = model else {
            requestedAmountRow?.removeFromSuperview()
            requestedAmountRow = nil
            return
        }

        if requestedAmountRow == nil {
            let requestedAmountView = RequestedAmountRow(frame: .zero)
            containerView.stackView.insertArranged(view: requestedAmountView, after: titleView)
            requestedAmountRow = requestedAmountView
        }

        requestedAmountRow?.bind(viewModel: requestedAmountViewModel)
    }

    private func createHeader(with text: String) -> StackTableHeaderCell {
        let headerView = StackTableHeaderCell()
        headerView.titleLabel.apply(style: .footnoteWhite64)
        headerView.titleLabel.text = text
        return headerView
    }
}
