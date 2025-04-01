import UIKit
import SubstrateSdk
import Foundation_iOS

final class ReferendumDetailsViewController: UIViewController, ViewHolder {
    typealias RootViewType = ReferendumDetailsViewLayout

    let presenter: ReferendumDetailsPresenterProtocol
    let localizationManager: LocalizationManagerProtocol

    private var dAppCells: [ReferendumDAppCellView]?

    init(
        presenter: ReferendumDetailsPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.localizationManager = localizationManager

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ReferendumDetailsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupNavigationItem()
        setupHandlers()

        presenter.setup()
    }

    private func setupNavigationItem() {
        navigationItem.rightBarButtonItem = rootView.shareButton
        rootView.shareButton.target = self
        rootView.shareButton.action = #selector(actionShare)
    }

    private func setupHandlers() {
        rootView.votingDetailsRow.voteButton.addTarget(
            self,
            action: #selector(actionVote),
            for: .touchUpInside
        )

        rootView.titleView.accountContainerView.addTarget(
            self,
            action: #selector(actionProposer),
            for: .touchUpInside
        )

        rootView.titleView.moreButton.addTarget(
            self,
            action: #selector(actionFullDescription),
            for: .touchUpInside
        )

        rootView.votingDetailsRow.ayeVotesView.addTarget(
            self,
            action: #selector(actionAyeVotes),
            for: .touchUpInside
        )

        rootView.votingDetailsRow.nayVotesView.addTarget(
            self,
            action: #selector(actionNayVotes),
            for: .touchUpInside
        )

        rootView.votingDetailsRow.abstainVotesView.addTarget(
            self,
            action: #selector(actionAbstainVotes),
            for: .touchUpInside
        )

        rootView.fullDetailsView.addTarget(
            self,
            action: #selector(actionFullDetails),
            for: .touchUpInside
        )

        rootView.titleView.descriptionView.delegate = self
    }

    @objc private func actionVote() {
        presenter.vote()
    }

    @objc private func actionProposer() {
        presenter.showProposerDetails()
    }

    @objc private func actionFullDescription() {
        presenter.readFullDescription()
    }

    @objc private func actionAyeVotes() {
        presenter.showAyeVoters()
    }

    @objc private func actionNayVotes() {
        presenter.showNayVoters()
    }

    @objc private func actionAbstainVotes() {
        presenter.showAbstainVoters()
    }

    @objc private func actionShare() {
        presenter.share()
    }

    @objc private func actionDApp(_ sender: UIControl) {
        guard
            let cell = sender as? ReferendumDAppCellView,
            let index = dAppCells?.firstIndex(of: cell) else {
            return
        }

        presenter.opeDApp(at: index)
    }

    @objc private func actionFullDetails() {
        presenter.openFullDetails()
    }
}

extension ReferendumDetailsViewController: ReferendumDetailsViewProtocol {
    func didReceive(votingDetails: ReferendumVotingStatusDetailsView.Model) {
        rootView.votingDetailsRow.bind(viewModel: votingDetails)
    }

    func didReceive(dAppModels: [DAppView.Model]?) {
        let cells = rootView.setDApps(models: dAppModels, locale: localizationManager.selectedLocale)
        dAppCells = cells

        cells.forEach { $0.addTarget(self, action: #selector(actionDApp(_:)), for: .touchUpInside) }
    }

    func didReceive(timelineModel: [ReferendumTimelineView.Model]?) {
        rootView.setTimeline(model: timelineModel, locale: localizationManager.selectedLocale)
    }

    func didReceive(titleModel: ReferendumDetailsTitleView.Model) {
        rootView.titleView.bind(viewModel: titleModel, locale: localizationManager.selectedLocale)

        rootView.setNeedsLayout()
    }

    func didReceive(yourVoteModel: [YourVoteRow.Model]) {
        rootView.setYourVote(model: yourVoteModel)
    }

    func didReceive(requestedAmount: RequestedAmountRow.Model?) {
        rootView.setRequestedAmount(model: requestedAmount)
    }

    func didReceive(trackTagsModel: TrackTagsView.Model?) {
        let view = trackTagsModel.map {
            let tracksTagsView = TrackTagsView()
            tracksTagsView.bind(viewModel: $0)
            return tracksTagsView
        }

        navigationItem.titleView = view
    }

    func didReceive(shouldHideFullDetails: Bool) {
        rootView.setFullDetails(hidden: shouldHideFullDetails, locale: localizationManager.selectedLocale)
    }

    func didReceive(activeTimeViewModel: ReferendumInfoView.Time?) {
        rootView.votingDetailsRow.statusView.bind(timeModel: activeTimeViewModel)
        rootView.timelineView.bind(activeTimeViewModel: activeTimeViewModel)
    }
}

extension ReferendumDetailsViewController: MarkdownViewContainerDelegate {
    func markdownView(_: MarkdownViewContainer, asksHandle url: URL) {
        presenter.openURL(url)
    }
}
