import UIKit

final class ReferendumDetailsViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 24, right: 16)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        return view
    }()

    let titleView = ReferendumDetailsTitleView()
    let votingDetailsRow = ReferendumVotingStatusDetailsView()
    let dAppsTableView = StackTableView()
    var timelineTableView = StackTableView()

    var yourVoteRow: YourVoteRow?
    var requestedAmountRow: RequestedAmountRow?

    let fullDetailsView = FullDetailsRow(frame: .zero)

    override init(frame: CGRect) {
        super.init(frame: frame)

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
        containerView.stackView.addArrangedSubview(timelineTableView)
        containerView.stackView.addArrangedSubview(fullDetailsView)

        timelineTableView.apply(style: .cellWithoutHighlighting)
        dAppsTableView.apply(style: .cellWithoutHighlighting)
    }

    func setTimeline(title: String, model: ReferendumTimelineView.Model?) {
        timelineTableView.clear()
        guard let model = model else {
            return
        }
        let headerView = createHeader(with: title)
        let timelineRow = TimelineRow(frame: .zero)
        timelineRow.bind(viewModel: model)
        timelineTableView.stackView.addArrangedSubview(headerView)
        timelineTableView.stackView.addArrangedSubview(timelineRow)
    }

    func setDApps(title: String, models: [ReferendumDAppView.Model]) {
        dAppsTableView.clear()

        let headerView = createHeader(with: title)
        dAppsTableView.stackView.addArrangedSubview(headerView)
        for model in models {
            let dAppView = ReferendumDAppCellView(frame: .zero)
            dAppView.rowContentView.bind(viewModel: model)
            dAppsTableView.stackView.addArrangedSubview(dAppView)
        }
    }

    func setYourVote(model: YourVoteRow.Model?) {
        guard let yourVoteViewModel = model else {
            yourVoteRow.map(containerView.stackView.removeArrangedSubview)
            return
        }
        if yourVoteRow == nil {
            let yourVoteView = YourVoteRow(frame: .zero)
            containerView.stackView.addArrangedSubview(yourVoteView)
            yourVoteRow = yourVoteView
        }
        yourVoteRow?.bind(viewModel: yourVoteViewModel)
    }

    func setRequestedAmount(model: RequestedAmountRow.Model?) {
        guard let requestedAmountViewModel = model else {
            requestedAmountRow.map(containerView.stackView.removeArrangedSubview)
            return
        }
        if requestedAmountRow == nil {
            let requestedAmountView = RequestedAmountRow(frame: .zero)
            containerView.stackView.addArrangedSubview(requestedAmountView)
            requestedAmountRow = requestedAmountView
        }
        requestedAmountRow?.bind(viewModel: requestedAmountViewModel)
    }

    private func createHeader(with text: String) -> StackTableHeaderCell {
        let headerView = StackTableHeaderCell()
        headerView.titleLabel.apply(style: .footnoteWhite64)
        headerView.titleLabel.text = text
        headerView.contentInsets = .init(top: 16, left: 16, bottom: 8, right: 16)
        return headerView
    }
}
