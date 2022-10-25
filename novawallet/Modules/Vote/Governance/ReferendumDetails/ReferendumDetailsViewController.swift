import UIKit
import SubstrateSdk
import SoraFoundation

final class ReferendumDetailsViewController: UIViewController, ViewHolder {
    typealias RootViewType = ReferendumDetailsViewLayout

    let presenter: ReferendumDetailsPresenterProtocol
    let localizationManager: LocalizationManagerProtocol

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

        setupHandlers()

        presenter.setup()
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
}

extension ReferendumDetailsViewController: ReferendumDetailsViewProtocol {
    func didReceive(votingDetails: ReferendumVotingStatusDetailsView.Model) {
        rootView.votingDetailsRow.bind(viewModel: votingDetails)
    }

    func didReceive(dAppModels: [ReferendumDAppView.Model]?) {
        rootView.setDApps(models: dAppModels, locale: localizationManager.selectedLocale)
    }

    func didReceive(timelineModel: [ReferendumTimelineView.Model]?) {
        rootView.setTimeline(model: timelineModel, locale: localizationManager.selectedLocale)
    }

    func didReceive(titleModel: ReferendumDetailsTitleView.Model) {
        rootView.titleView.bind(viewModel: titleModel, locale: localizationManager.selectedLocale)
    }

    func didReceive(yourVoteModel: YourVoteRow.Model?) {
        rootView.setYourVote(model: yourVoteModel)
    }

    func didReceive(requestedAmount: RequestedAmountRow.Model?) {
        rootView.setRequestedAmount(model: requestedAmount)
    }

    func didReceive(trackTagsModel: TrackTagsView.Model?) {
        let barButtonItem: UIBarButtonItem? = trackTagsModel.map {
            let trackTagsView = TrackTagsView()
            trackTagsView.bind(viewModel: $0)
            return .init(customView: trackTagsView)
        }
        navigationItem.setRightBarButton(barButtonItem, animated: true)
    }
}
