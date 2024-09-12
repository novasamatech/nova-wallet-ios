import Foundation
import SoraFoundation
import Operation_iOS

final class TinderGovPresenter {
    weak var view: TinderGovViewProtocol?
    let interactor: TinderGovInteractorInputProtocol
    let wireframe: TinderGovWireframeProtocol

    private let viewModelFactory: TinderGovViewModelFactoryProtocol
    private let cardsViewModelFactory: VoteCardViewModelFactoryProtocol
    private let localizationManager: LocalizationManagerProtocol

    private var model: TinderGovModelBuilder.Result.Model?
    private var votingPower: VotingPowerLocal?

    init(
        wireframe: TinderGovWireframeProtocol,
        interactor: TinderGovInteractorInputProtocol,
        viewModelFactory: TinderGovViewModelFactoryProtocol,
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

// MARK: TinderGovPresenterProtocol

extension TinderGovPresenter: TinderGovPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func actionBack() {
        wireframe.back(from: view)
    }

    func actionSettings() {
        guard let referendumId = model?.referendums.first?.index else {
            return
        }

        let initData = ReferendumVotingInitData(presetVotingPower: votingPower)

        wireframe.showVoteSetup(
            from: view,
            referendum: referendumId,
            initData: initData
        )
    }
}

// MARK: TinderGovInteractorOutputProtocol

extension TinderGovPresenter: TinderGovInteractorOutputProtocol {
    func didReceive(_ modelBuilderResult: TinderGovModelBuilder.Result) {
        model = modelBuilderResult.model

        switch modelBuilderResult.changeKind {
        case .setup:
            updateVotingListView()
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

private extension TinderGovPresenter {
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

    func onTopCardAppear(referendumId _: ReferendumIdLocal) {}

    func updateCardsStackView() {
        guard let model else { return }

        let inserts = createCardViewModel(from: model.referendumsChanges.inserts)
        let updates = createCardViewModel(from: model.referendumsChanges.updates)
            .reduce(into: [:]) { $0[$1.id] = $1 }
        let deletes = Set(model.referendumsChanges.deletes)

        let stackChangeModel = CardsZStackChangeModel(
            inserts: inserts,
            updates: updates,
            deletes: deletes
        )

        view?.updateCardsStack(with: stackChangeModel)
    }

    func createCardViewModel(from referendums: [ReferendumLocal]) -> [VoteCardViewModel] {
        cardsViewModelFactory.createVoteCardViewModels(
            from: referendums,
            locale: localizationManager.selectedLocale,
            onVote: { [weak self] voteResult, id in
                self?.onReferendumVote(voteResult: voteResult, id: id)
            },
            onBecomeTop: { [weak self] id in
                self?.onTopCardAppear(referendumId: id)
            },
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
}
