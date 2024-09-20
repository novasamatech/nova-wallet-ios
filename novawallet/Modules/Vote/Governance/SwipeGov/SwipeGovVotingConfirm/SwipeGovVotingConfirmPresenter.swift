import Foundation
import SoraFoundation

final class SwipeGovVotingConfirmPresenter: BaseReferendumVoteConfirmPresenter {
    weak var view: SwipeGovVotingConfirmViewProtocol? {
        get { baseView as? SwipeGovVotingConfirmViewProtocol }
        set { baseView = newValue }
    }

    private let interactor: SwipeGovVotingConfirmInteractorInputProtocol
    private let wireframe: SwipeGovVotingConfirmWireframeProtocol

    private var votingItems: [VotingBasketItemLocal] = []
    private var referendums: [ReferendumIdLocal: ReferendumLocal] = [:]

    init(
        initData: ReferendumVotingInitData,
        chain: ChainModel,
        selectedAccount: MetaChainAccountResponse,
        dataValidatingFactory: GovernanceValidatorFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        referendumFormatter: LocalizableResource<NumberFormatter>,
        referendumStringsViewModelFactory: ReferendumDisplayStringFactoryProtocol,
        lockChangeViewModelFactory: ReferendumLockChangeViewModelFactoryProtocol,
        interactor: SwipeGovVotingConfirmInteractorInputProtocol,
        wireframe: SwipeGovVotingConfirmWireframeProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        votingItems = initData.votingItems ?? []

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

    override func provideAmountViewModel() {
        guard
            let precision = chain.utilityAsset()?.displayInfo.assetPrecision,
            let amount = votingItems.max(by: { $0.amount < $1.amount })?.amount,
            let decimalAmount = Decimal.fromSubstrateAmount(
                amount,
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
            newVotes: votingItems.mapToVotes(),
            blockHash: votesResult?.blockHash
        )
    }

    override func refreshFee() {
        interactor.estimateFee(for: votingItems.mapToVotes())
    }

    override func confirm() {
        guard let assetInfo = chain.utilityAssetDisplayInfo() else {
            return
        }

        let referendums = votingItems.compactMap { self.referendums[$0.referendumId] }

        let params = GovernanceVoteBatchValidatingParams(
            assetBalance: assetBalance,
            referendums: referendums,
            votes: votesResult?.value?.votes,
            newVotes: votingItems.mapToVotes(),
            fee: fee,
            assetInfo: assetInfo
        )

        let handlers = GovernanceVoteValidatingHandlers(
            feeErrorClosure: { [weak self] in
                self?.refreshFee()
            }
        )

        DataValidationRunner.validateVotesBatch(
            factory: dataValidatingFactory,
            params: params,
            selectedLocale: selectedLocale,
            handlers: handlers,
            successClosure: { [weak self] in
                guard let self else { return }
                view?.didStartLoading()
                interactor.submit(votes: votingItems.mapToVotes())
            },
            maxAmountErrorClosure: { [weak self] in
                guard let self, let assetBalance else { return }
                view?.didStartLoading()
                interactor.submit(
                    votes: votingItems.mapToVotes(),
                    limitingBy: assetBalance.freeInPlank
                )
            }
        )
    }

    override func setup() {
        super.setup()

        view?.didReceive(referendaCount: votingItems.count)
    }

    override func didReceiveVotingReferendumsState(_ state: ReferendumsState) {
        super.didReceiveVotingReferendumsState(state)

        referendums = state.referendums
    }
}

extension SwipeGovVotingConfirmPresenter: SwipeGovVotingConfirmInteractorOutputProtocol {
    func didReceiveSuccessBatchVoting() {
        view?.didStopLoading()

        wireframe.presentExtrinsicSubmission(
            from: view,
            completionAction: .dismissAllModals,
            locale: selectedLocale
        )
    }
}

extension SwipeGovVotingConfirmPresenter: SwipeGovVotingConfirmPresenterProtocol {}
