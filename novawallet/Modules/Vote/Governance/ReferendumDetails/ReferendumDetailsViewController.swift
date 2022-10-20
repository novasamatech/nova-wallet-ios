import UIKit
import SubstrateSdk

final class ReferendumDetailsViewController: UIViewController, ViewHolder {
    typealias RootViewType = ReferendumDetailsViewLayout

    let presenter: ReferendumDetailsPresenterProtocol

    init(presenter: ReferendumDetailsPresenterProtocol) {
        self.presenter = presenter
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

        presenter.setup()
        setSamples()
    }

    private func setSamples() {
        let status = ReferendumVotingStatusView.Model(
            status: .init(name: "PASSING", kind: .positive),
            time: .init(titleIcon: .init(title: "Approve in 03:59:59", icon: R.image.iconFire()), isUrgent: true),
            title: "Voting status"
        )
        let votingProgress = VotingProgressView.Model(
            support: .init(title: "Threshold reached", icon: R.image.iconCheckmark()?.withTintColor(R.color.colorGreen15CF37()!)),
            approval: .init(
                passThreshold: 0.5,
                ayeProgress: 0.9,
                ayeMessage: "Aye: 99.9%",
                passMessage: "To pass: 50%",
                nayMessage: "Nay: 0.1%"
            )
        )
        didReceive(votingDetails: .init(
            status: status,
            votingProgress: votingProgress,
            aye: .init(
                title: "Aye",
                votes: "25,354.16 votes",
                tokens: "16,492 KSM"
            ),
            nay: .init(
                title: "Nay",
                votes: "1.5 votes",
                tokens: "149 KSM"
            ),
            buttonText: "Vote"
        ))

        let iconUrl = URL(string: "https://raw.githubusercontent.com/nova-wallet/nova-utils/master/icons/chains/white/Polkadot.svg")!
        didReceive(dAppModels: [
            .init(
                icon: RemoteImageViewModel(url: iconUrl),
                title: "Polkassembly",
                subtitle: "Comment and react"
            )
        ])

        let metaAccount = MetaAccountModel(
            metaId: UUID().uuidString,
            name: UUID().uuidString,
            substrateAccountId: Data.random(of: 32)!,
            substrateCryptoType: 0,
            substratePublicKey: Data.random(of: 32)!,
            ethereumAddress: Data.random(of: 20)!,
            ethereumPublicKey: Data.random(of: 32)!,
            chainAccounts: [],
            type: .secrets
        )

        let optIcon = metaAccount.walletIdenticonData().flatMap { try? PolkadotIconGenerator().generateFromAccountId($0) }
        let iconViewModel = optIcon.map { DrawableIconViewModel(icon: $0) }

        didReceive(trackTagsModel: .init(
            titleIcon: .init(title: "main agenda", icon: nil),
            referendumNumber: "224"
        ))
        didReceive(titleModel: .init(
            accountIcon: iconViewModel,
            accountName: "RTTI-5220",
            title: "Polkadot and Kusama participation in the 10th Pais Digital Chile Summit.",
            description: "The Sovereign Nature Initiative transfers, Governance, Sovereign Nature Initiative (SNI) is a non-profit foundation that has" +
                "brought together multiple partners and engineers from the лоалыво одыо лоаыдвлоадо",
            buttonText: "Read more"
        )
        )

        didReceive(timelineModel: .init(title: "Timeline", statuses: [
            .init(title: "One", subtitle: .date("Sept 1, 2022 04:44:31"), isLast: false),
            .init(title: "Two", subtitle: .date("Sept 1, 2022 04:44:31"), isLast: false),
            .init(title: "Three", subtitle: .date("Sept 1, 2022 04:44:31"), isLast: false)
        ]))

        rootView.fullDetailsView.bind(title: "Full details")

        didReceive(yourVoteModel: .init(
            vote: .init(title: "AYE", description: "Your vote"),
            amount: .init(topValue: "30 votes", bottomValue: "10 KSM × 3x")
        ))

        didReceive(requestedAmount: .init(
            title: "Requested amount",
            amount: .init(topValue: "1,000 KSM", bottomValue: "$38,230")
        ))
    }
}

extension ReferendumDetailsViewController: ReferendumDetailsViewProtocol {
    func didReceive(votingDetails: ReferendumVotingStatusDetailsView.Model) {
        rootView.votingDetailsRow.bind(viewModel: votingDetails)
    }

    func didReceive(dAppModels: [ReferendumDAppView.Model]) {
        rootView.setDApps(models: dAppModels)
    }

    func didReceive(timelineModel: ReferendumTimelineView.Model) {
        rootView.timelineRow.bind(viewModel: timelineModel)
    }

    func didReceive(titleModel: ReferendumDetailsTitleView.Model) {
        rootView.titleView.bind(viewModel: titleModel)
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
