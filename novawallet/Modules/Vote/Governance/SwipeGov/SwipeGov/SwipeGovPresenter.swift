import Foundation
import Foundation_iOS
import Operation_iOS

final class SwipeGovPresenter {
    weak var view: SwipeGovViewProtocol?
    let interactor: SwipeGovInteractorInputProtocol
    let wireframe: SwipeGovWireframeProtocol

    private let viewModelFactory: SwipeGovViewModelFactoryProtocol
    private let cardsViewModelFactory: VoteCardViewModelFactoryProtocol
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let localizationManager: LocalizationManagerProtocol
    private let utilityAssetInfo: AssetBalanceDisplayInfo
    private let govBalanceCalculator: AvailableBalanceMapping

    private var model: SwipeGovModelBuilder.Result.Model?
    private var votingPower: VotingPowerLocal?
    private var currentCardStackViewModel: CardsZStackViewModel?
    private var balanceStore: UncertainStorage<AssetBalance?> = .undefined

    init(
        wireframe: SwipeGovWireframeProtocol,
        interactor: SwipeGovInteractorInputProtocol,
        viewModelFactory: SwipeGovViewModelFactoryProtocol,
        cardsViewModelFactory: VoteCardViewModelFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        govBalanceCalculator: AvailableBalanceMapping,
        utilityAssetInfo: AssetBalanceDisplayInfo,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.wireframe = wireframe
        self.interactor = interactor
        self.viewModelFactory = viewModelFactory
        self.cardsViewModelFactory = cardsViewModelFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.govBalanceCalculator = govBalanceCalculator
        self.utilityAssetInfo = utilityAssetInfo
        self.localizationManager = localizationManager
    }
}

// MARK: SwipeGovPresenterProtocol

extension SwipeGovPresenter: SwipeGovPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func cardsStackBecameEmpty() {
        showVotingList()
    }

    func actionBack() {
        wireframe.back(from: view)
    }

    func actionSettings() {
        showVotingPower(nil)
    }

    func actionVotingList() {
        showVotingList()
    }
}

// MARK: SwipeGovInteractorOutputProtocol

extension SwipeGovPresenter: SwipeGovInteractorOutputProtocol {
    func didReceiveState(_ modelBuilderResult: SwipeGovModelBuilder.Result) {
        model = modelBuilderResult.model

        updateVotingListView()
        updateCardsStackView()
        updateReferendumsCounter()
        updateSettingsState()
    }

    func didReceiveVotingPower(_ votingPower: VotingPowerLocal) {
        self.votingPower = votingPower
    }

    func didReceiveBalace(_ assetBalance: AssetBalance?) {
        balanceStore = .defined(assetBalance)
    }
}

// MARK: - Private

private extension SwipeGovPresenter {
    func showVotingList() {
        wireframe.showVotingList(from: view)
    }

    func onReferendumVote(
        voteResult: VoteResult,
        id: ReferendumIdLocal
    ) {
        guard voteResult != .skip, let votingPower else {
            return
        }

        interactor.addVoting(with: voteResult, for: id, votingPower: votingPower)
    }

    func updateCardsStackView() {
        guard let model else { return }

        let cardActions = VoteCardViewModel.Actions(
            onAction: { [weak self] referendumId in
                self?.showDetails(for: referendumId)
            },
            onVote: { [weak self] voteResult, id in
                self?.onReferendumVote(voteResult: voteResult, id: id)
            },
            onBecomeTop: { _ in },
            onLoadError: { [weak self] handlers in
                guard let self else { return }
                wireframe.presentRequestStatus(
                    on: view,
                    locale: localizationManager.selectedLocale,
                    retryAction: { handlers.retry() },
                    skipAction: { self.view?.skipCard() }
                )
            }
        )

        let stackActions = CardsZStack.Actions(
            emptyViewAction: { [weak self] in self?.showVotingList() },
            validationClosure: { [weak self] cardViewModel, voteResult in
                guard let self else { return false }

                return validateVotingAvailable(
                    for: cardViewModel,
                    voteResult: voteResult
                )
            }
        )

        let viewModel = cardsViewModelFactory.createCardsStackViewModel(
            from: model,
            currentViewModel: currentCardStackViewModel,
            locale: localizationManager.selectedLocale,
            cardActions: cardActions,
            stackActions: stackActions
        )
        currentCardStackViewModel = viewModel

        view?.updateCardsStack(with: viewModel)
    }

    func validateVotingAvailable(
        for cardViewModel: VoteCardViewModel,
        voteResult: VoteResult
    ) -> Bool {
        guard voteResult != .skip else {
            return true
        }

        guard let votingPower else {
            interruptAndSetVotingPower(for: cardViewModel.id, voteResult: voteResult)
            return false
        }

        guard case let .defined(optBalance) = balanceStore else {
            return false
        }

        let availableBalance = govBalanceCalculator.availableBalanceElseZero(from: optBalance)

        if availableBalance == 0 || votingPower.amount > availableBalance {
            interruptAndOfferChangeVotingPower(
                from: votingPower,
                cardViewModel: cardViewModel,
                voteResult: voteResult
            )

            return false
        }

        return true
    }

    func updateVotingListView() {
        guard let model else { return }

        let viewModel = viewModelFactory.createVotingListViewModel(
            from: model.votingList,
            locale: localizationManager.selectedLocale
        )
        view?.updateVotingList(with: viewModel)
    }

    func updateReferendumsCounter() {
        guard let viewModel = viewModelFactory.createReferendumsCounterViewModel(
            availableToVoteCount: currentCardStackViewModel?.allCards.count ?? 0,
            locale: localizationManager.selectedLocale
        ) else {
            return
        }

        view?.updateCardsCounter(with: viewModel)
    }

    func updateSettingsState() {
        let isStackEmpty = currentCardStackViewModel?.stackIsEmpty ?? true
        view?.didReceive(canOpenSettings: !isStackEmpty)
    }

    func interruptAndSetVotingPower(for cardId: VoteCardId, voteResult: VoteResult) {
        showVotingPower { [weak self] newVotingPower in
            self?.votingPower = newVotingPower
            self?.view?.didUpdateVotingPower(for: cardId, voteResult: voteResult)
        }
    }

    func showVotingPower(_ completionClosure: VotingPowerLocalSetClosure?) {
        guard let referendum = model?.referendums.first else {
            return
        }

        let initData = ReferendumVotingInitData(
            referendum: referendum,
            presetVotingPower: votingPower
        )

        wireframe.showVoteSetup(
            from: view,
            initData: initData,
            newVotingPowerClosure: completionClosure
        )
    }

    func showDetails(for referendumId: ReferendumIdLocal) {
        guard let referendum = model?.referendums.first(
            where: { $0.index == referendumId }
        ) else {
            return
        }

        let initData = ReferendumDetailsInitData(referendum: referendum)

        wireframe.showReferendumDetails(
            from: view,
            initData: initData
        )
    }

    func interruptAndOfferChangeVotingPower(
        from oldVotingPower: VotingPowerLocal,
        cardViewModel: VoteCardViewModel,
        voteResult: VoteResult
    ) {
        let voteAmount = balanceViewModelFactory.amountFromValue(
            oldVotingPower.amount.decimal(assetInfo: utilityAssetInfo)
        ).value(for: localizationManager.selectedLocale)

        let model = SwipeGovBalanceAlertModel(
            votingAmount: voteAmount,
            votingConviction: oldVotingPower.conviction.displayValue
        )

        wireframe.presentBalanceAlert(
            from: view,
            model: model,
            locale: localizationManager.selectedLocale
        ) { [weak self] in
            self?.interruptAndSetVotingPower(for: cardViewModel.id, voteResult: voteResult)
        }
    }
}
