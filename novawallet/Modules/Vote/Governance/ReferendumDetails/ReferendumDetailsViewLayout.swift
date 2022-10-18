import UIKit

final class ReferendumDetailsViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        return view
    }()

    let titleView = ReferendumDetailsTitleView()
    let votingStatusView = ReferendumVotingStatusView()
    let dAppsTableView = StackTableView()
    let timelineTableView = ReferendumTimelineView()

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

        containerView.stackView.addArrangedSubview(titleView)
        containerView.stackView.setCustomSpacing(16, after: titleView)

        containerView.stackView.addArrangedSubview(votingStatusView)
        containerView.stackView.setCustomSpacing(12, after: votingStatusView)

        containerView.stackView.addArrangedSubview(timelineTableView)
        containerView.stackView.setCustomSpacing(12, after: dAppsTableView)
    }

    func setDApps(models: [ReferendumDAppView.Model]) {
        models.forEach {
            let dAppView = ReferendumDAppCellView()
            dAppView.rowContentView.bind(viewModel: $0)
            dAppsTableView.addArrangedSubview(dAppView)
        }
    }
}

final class ReferendumDAppCellView: RowView<ReferendumDAppView>, StackTableViewCellProtocol {}
