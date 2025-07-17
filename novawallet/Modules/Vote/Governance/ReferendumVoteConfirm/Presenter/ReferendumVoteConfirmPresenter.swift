import Foundation
import BigInt
import Foundation_iOS

final class ReferendumVoteConfirmPresenter: BaseReferendumVoteConfirmPresenter {
    weak var view: ReferendumVoteConfirmViewProtocol? {
        get { baseView as? ReferendumVoteConfirmViewProtocol }
        set { baseView = newValue }
    }

    let interactor: ReferendumVoteConfirmInteractorInputProtocol
    let wireframe: ReferendumVoteConfirmWireframeProtocol

    let vote: ReferendumNewVote

    private var referendum: ReferendumLocal?

    private let referendumId: ReferendumIdLocal

    init(
        initData: ReferendumVotingInitData,
        referendumId: ReferendumIdLocal,
        vote: ReferendumNewVote,
        chain: ChainModel,
        selectedAccount: MetaChainAccountResponse,
        dataValidatingFactory: GovernanceValidatorFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        referendumFormatter: LocalizableResource<NumberFormatter>,
        referendumStringsViewModelFactory: ReferendumDisplayStringFactoryProtocol,
        lockChangeViewModelFactory: ReferendumLockChangeViewModelFactoryProtocol,
        interactor: ReferendumVoteConfirmInteractorInputProtocol,
        wireframe: ReferendumVoteConfirmWireframeProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.vote = vote
        self.referendumId = referendumId

        super.init(
            initData: initData,
            chain: chain,
            selectedAccount: selectedAccount,
            dataValidatingFactory: dataValidatingFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            referendumFormatter: referendumFormatter,
            referendumStringsViewModelFactory: referendumStringsViewModelFactory,
            lockChangeViewModelFactory: lockChangeViewModelFactory,
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: localizationManager,
            logger: logger
        )
    }

    private func provideReferendumIndex() {
        let referendumString = referendumFormatter.value(for: selectedLocale).string(from: vote.index as NSNumber)
        view?.didReceive(referendumNumber: referendumString ?? "")
    }

    private func provideYourVoteViewModel() {
        let votesString = referendumStringsViewModelFactory.createVotes(
            from: vote.voteAction.conviction().votes(for: vote.voteAction.amount()) ?? 0,
            chain: chain,
            locale: selectedLocale
        )

        let convictionString = referendumStringsViewModelFactory.createVotesDetails(
            from: vote.voteAction.amount(),
            conviction: vote.voteAction.conviction().decimalValue,
            chain: chain,
            locale: selectedLocale
        )

        let voteSideString: String
        let voteSideStyle: YourVoteView.Style

        switch vote.voteAction {
        case .aye:
            voteSideString = R.string.localizable.governanceAye(preferredLanguages: selectedLocale.rLanguages)
            voteSideStyle = .ayeInverse
        case .nay:
            voteSideString = R.string.localizable.governanceNay(preferredLanguages: selectedLocale.rLanguages)
            voteSideStyle = .nayInverse
        case .abstain:
            voteSideString = R.string.localizable.governanceAbstain(preferredLanguages: selectedLocale.rLanguages)
            voteSideStyle = .abstainInverse
        }

        let voteDescription = R.string.localizable.govYourVote(preferredLanguages: selectedLocale.rLanguages)

        let viewModel = YourVoteRow.Model(
            vote: .init(title: voteSideString.uppercased(), description: voteDescription, style: voteSideStyle),
            amount: .init(topValue: votesString ?? "", bottomValue: convictionString)
        )

        view?.didReceiveYourVote(viewModel: viewModel)
    }

    override func provideAmountViewModel() {
        guard
            let precision = chain.utilityAsset()?.displayInfo.assetPrecision,
            let decimalAmount = Decimal.fromSubstrateAmount(
                vote.voteAction.amount(),
                precision: precision
            ) else {
            return
        }

        let viewModel = balanceViewModelFactory.balanceFromPrice(
            decimalAmount,
            priceData: priceData
        ).value(for: selectedLocale)

        baseView?.didReceiveAmount(viewModel: viewModel)
    }

    override func refreshLockDiff() {
        guard let trackVoting = votesResult?.value else {
            return
        }

        interactor.refreshLockDiff(
            for: trackVoting,
            newVotes: [vote]
        )
    }

    override func refreshFee() {
        interactor.estimateFee(for: [vote])
    }

    override func updateView() {
        super.updateView()
        provideReferendumIndex()
        provideYourVoteViewModel()
    }

    override func confirm() {
        guard let assetInfo = chain.utilityAssetDisplayInfo() else {
            return
        }

        let params = GovernanceVoteValidatingParams(
            assetBalance: assetBalance,
            referendum: referendum,
            newVote: vote,
            selectedConviction: vote.voteAction.conviction(),
            fee: fee,
            votes: votesResult?.value?.votes,
            assetInfo: assetInfo
        )

        let handlers = GovernanceVoteValidatingHandlers(
            feeErrorClosure: { [weak self] in
                self?.refreshFee()
            }
        )

        DataValidationRunner.validateVote(
            factory: dataValidatingFactory,
            params: params,
            selectedLocale: selectedLocale,
            handlers: handlers,
            successClosure: { [weak self] in
                guard let self else {
                    return
                }

                view?.didStartLoading()
                interactor.submit(vote: vote)
            }
        )
    }

    override func didReceiveVotingReferendumsState(_ state: ReferendumsState) {
        super.didReceiveVotingReferendumsState(state)

        referendum = state.referendums[referendumId]
    }
}

// MARK: ReferendumVoteConfirmInteractorOutputProtocol

extension ReferendumVoteConfirmPresenter: ReferendumVoteConfirmInteractorOutputProtocol {
    func didReceiveVotingCompletion(_ sender: ExtrinsicSenderResolution) {
        // TODO: MS navigation
        view?.didStopLoading()

        wireframe.presentExtrinsicSubmission(
            from: baseView,
            sender: sender,
            completionAction: .dismiss,
            locale: selectedLocale
        )
    }
}
