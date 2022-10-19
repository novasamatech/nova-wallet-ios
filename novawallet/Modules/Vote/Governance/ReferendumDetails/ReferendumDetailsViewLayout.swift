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
    let votingDetailsRow = VotingDetailsRow(frame: .zero)
    let dAppsTableView = StackTableView()
    let timelineRow = TimelineRow(frame: .zero)

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
        containerView.stackView.addArrangedSubview(timelineRow)
        containerView.stackView.addArrangedSubview(fullDetailsView)
    }

    func setDApps(models: [ReferendumDAppView.Model]) {
        dAppsTableView.clear()

        for model in models {
            let dAppView = ReferendumDAppCellView(frame: .zero)
            dAppView.rowContentView.bind(viewModel: model)
            dAppsTableView.stackView.addArrangedSubview(dAppView)
        }
    }

    func setYourVote(model: YourVoteRow.Model) {
        if yourVoteRow == nil {
            let yourVoteView = YourVoteRow(frame: .zero)
            containerView.stackView.addArrangedSubview(yourVoteView)
            yourVoteRow = yourVoteView
        }
        yourVoteRow?.bind(viewModel: model)
    }

    func removeYourVote() {
        guard let yourVoteRow = yourVoteRow else {
            return
        }
        containerView.stackView.removeArrangedSubview(yourVoteRow)
    }

    func setRequestedAmount(model: RequestedAmountRow.Model) {
        if requestedAmountRow == nil {
            let requestedAmountView = RequestedAmountRow(frame: .zero)
            containerView.stackView.addArrangedSubview(requestedAmountView)
            requestedAmountRow = requestedAmountView
        }
        requestedAmountRow?.bind(viewModel: model)
    }

    func removeRequestedAmount() {
        guard let requestedAmountRow = requestedAmountRow else {
            return
        }
        containerView.stackView.removeArrangedSubview(requestedAmountRow)
    }
}
