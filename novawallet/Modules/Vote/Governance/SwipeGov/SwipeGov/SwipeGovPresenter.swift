import Foundation
import SoraFoundation
import Operation_iOS

final class SwipeGovPresenter {
    weak var view: SwipeGovViewProtocol?
    let interactor: SwipeGovInteractorInputProtocol
    let wireframe: SwipeGovWireframeProtocol

    private let viewModelFactory: SwipeGovViewModelFactoryProtocol
    private let cardsViewModelFactory: VoteCardViewModelFactoryProtocol
    private let localizationManager: LocalizationManagerProtocol

    private var model: SwipeGovModelBuilder.Result.Model?
    private var votingPower: VotingPowerLocal?
    private var currentCardStackViewModel: CardsZStackViewModel?

    init(
        wireframe: SwipeGovWireframeProtocol,
        interactor: SwipeGovInteractorInputProtocol,
        viewModelFactory: SwipeGovViewModelFactoryProtocol,
        cardsViewModelFactory: VoteCardViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.wireframe = wireframe
        self.interactor = interactor
        self.viewModelFactory = viewModelFactory
        self.cardsViewModelFactory = cardsViewModelFactory
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
        showVotingPower()
    }

    func actionVotingList() {
        showVotingList()
    }
}

// MARK: SwipeGovInteractorOutputProtocol

extension SwipeGovPresenter: SwipeGovInteractorOutputProtocol {
    func didReceive(_ modelBuilderResult: SwipeGovModelBuilder.Result) {
        model = modelBuilderResult.model

        switch modelBuilderResult.changeKind {
        case .referendums:
            updateCardsStackView()
        case .full:
            updateVotingListView()
            updateCardsStackView()
        }

        updateReferendumsCounter()
    }

    func didReceive(_ votingPower: VotingPowerLocal) {
        self.votingPower = votingPower
    }

    func didReceive(_ error: any Error) {
        wireframe.present(
            error: error,
            from: view,
            locale: localizationManager.selectedLocale
        )
    }
}

// MARK: - Private

private extension SwipeGovPresenter {
    func showVotingList() {
        guard let metaId = votingPower?.metaId else {
            return
        }

        wireframe.showVotingList(
            from: view,
            metaId: metaId
        )
    }

    func onReferendumVote(
        voteResult: VoteResult,
        id: ReferendumIdLocal
    ) {
        guard voteResult != .skip else {
            return
        }

        interactor.addVoting(
            with: voteResult,
            for: id
        )
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

        let viewModel = cardsViewModelFactory.createCardsStackViewModel(
            from: model,
            currentViewModel: currentCardStackViewModel,
            locale: localizationManager.selectedLocale,
            actions: cardActions,
            emptyViewAction: { [weak self] in self?.showVotingList() },
            validationClosure: { [weak self] _ in
                guard let self else { return false }

                return validateVotingAvailable()
            }
        )
        currentCardStackViewModel = viewModel

        view?.updateCardsStack(with: viewModel)
    }

    func validateVotingAvailable() -> Bool {
        let votingAvailable = votingPower != nil

        if !votingAvailable {
            showVotingPower()
        }

        return votingAvailable
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
        guard let model, !model.referendums.isEmpty else { return }

        guard let viewModel = viewModelFactory.createReferendumsCounterViewModel(
            referendums: model.referendums,
            votingList: model.votingList,
            locale: localizationManager.selectedLocale
        ) else {
            return
        }

        view?.updateCardsCounter(with: viewModel)
    }

    func showVotingPower() {
        guard let referendum = model?.referendums.first else {
            return
        }

        let initData = ReferendumVotingInitData(
            referendum: referendum,
            presetVotingPower: votingPower
        )

        wireframe.showVoteSetup(
            from: view,
            initData: initData
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
}
