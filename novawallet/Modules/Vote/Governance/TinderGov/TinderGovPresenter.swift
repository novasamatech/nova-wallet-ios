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

    private var referendums: [ReferendumIdLocal: ReferendumLocal] = [:]
    private var sortedReferendums: [ReferendumLocal] = []
    private var votingList: [ReferendumIdLocal] = []

    private let sorting: ReferendumsSorting

    init(
        wireframe: TinderGovWireframeProtocol,
        interactor: TinderGovInteractorInputProtocol,
        viewModelFactory: TinderGovViewModelFactoryProtocol,
        cardsViewModelFactory: VoteCardViewModelFactoryProtocol,
        sorting: ReferendumsSorting,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.wireframe = wireframe
        self.interactor = interactor
        self.viewModelFactory = viewModelFactory
        self.cardsViewModelFactory = cardsViewModelFactory
        self.sorting = sorting
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
}

// MARK: TinderGovInteractorOutputProtocol

extension TinderGovPresenter: TinderGovInteractorOutputProtocol {
    func didReceive(_ changes: [DataProviderChange<ReferendumLocal>]) {
        referendums = changes.mergeToDict(referendums)

        sortedReferendums = referendums.values.sorted {
            sorting.compare(
                referendum1: $0,
                referendum2: $1
            )
        }

        var inserts: [ReferendumLocal] = []
        var updates: [ReferendumLocal] = []
        var deletes: [ReferendumIdLocal] = []

        changes.forEach { change in
            if case let .insert(item) = change {
                inserts.append(item)
            } else if case let .update(item) = change {
                updates.append(item)
            } else if change.isDeletion {
                deletes.append(change.itemIdentifier())
            }
        }

        updateViews(
            inserting: inserts,
            updating: updates,
            deleting: deletes
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

        votingList.append(id)

        updateVotingListView()
    }

    func onTopCardAppear(referendumId: ReferendumIdLocal) {
        updateReferendumsCounter(currentReferendumId: referendumId)
    }

    func updateViews(
        inserting: [ReferendumLocal],
        updating: [ReferendumLocal],
        deleting: [ReferendumIdLocal]
    ) {
        guard let firstReferendum = sortedReferendums.first else {
            return
        }

        updateCardsStackView(
            inserting: inserting,
            updating: updating,
            deleting: deleting
        )
        updateVotingListView()
        updateReferendumsCounter(currentReferendumId: firstReferendum.index)
    }

    func updateCardsStackView(
        inserting: [ReferendumLocal],
        updating: [ReferendumLocal],
        deleting: [ReferendumIdLocal]
    ) {
        let sortedInserting = inserting.sorted {
            sorting.compare(
                referendum1: $0,
                referendum2: $1
            )
        }

        let inserts = createCardViewModel(from: sortedInserting)
        let updates = createCardViewModel(from: updating).reduce(into: [:]) { $0[$1.id] = $1 }
        let deletes = Set(deleting)

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
        let viewModel = viewModelFactory.createVotingListViewModel(
            from: votingList,
            locale: localizationManager.selectedLocale
        )
        view?.updateVotingList(with: viewModel)
    }

    func updateReferendumsCounter(currentReferendumId: ReferendumIdLocal) {
        guard let viewModel = viewModelFactory.createReferendumsCounterViewModel(
            currentReferendumId: currentReferendumId,
            referendums: sortedReferendums,
            locale: localizationManager.selectedLocale
        ) else {
            return
        }

        view?.updateCardsCounter(with: viewModel)
    }
}
