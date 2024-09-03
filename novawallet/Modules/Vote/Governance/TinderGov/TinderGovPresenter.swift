import Foundation

final class TinderGovPresenter {
    weak var view: TinderGovViewProtocol?
    let interactor: TinderGovInteractorInputProtocol
    let wireframe: TinderGovWireframeProtocol

    private let viewModelFactory: TinderGovViewModelFactoryProtocol

    private var referendums: [ReferendumLocal] = []
    private var votingList: [ReferendumIdLocal] = []

    init(
        wireframe: TinderGovWireframeProtocol,
        interactor: TinderGovInteractorInputProtocol,
        viewModelFactory: TinderGovViewModelFactoryProtocol
    ) {
        self.wireframe = wireframe
        self.interactor = interactor
        self.viewModelFactory = viewModelFactory
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
    func didReceive(_ referendums: [ReferendumLocal]) {
        guard let firstReferendum = referendums.first else {
            return
        }

        self.referendums = referendums

        updateCardsStackView()
        updateVotingListView()
        updateReferendumsCounter(currentReferendumId: firstReferendum.index)
    }
}

// MARK: - Private

private extension TinderGovPresenter {
    func onReferendumVote(
        voteResult _: VoteResult,
        id: ReferendumIdLocal
    ) {
        votingList.append(id)

        updateVotingListView()
    }

    func onTopCardAppear(referendumId: ReferendumIdLocal) {
        updateReferendumsCounter(currentReferendumId: referendumId)
    }

    func updateCardsStackView() {
        let cardViewModels = viewModelFactory.createVoteCardViewModels(
            from: referendums,
            onVote: { [weak self] voteResult, id in
                self?.onReferendumVote(voteResult: voteResult, id: id)
            },
            onBecomeTop: { [weak self] id in
                self?.onTopCardAppear(referendumId: id)
            }
        )

        view?.updateCards(with: cardViewModels)
    }

    func updateVotingListView() {
        let viewModel = viewModelFactory.createVotingListViewModel(from: votingList)
        view?.updateVotingList(with: viewModel)
    }

    func updateReferendumsCounter(currentReferendumId: ReferendumIdLocal) {
        guard let viewModel = viewModelFactory.createReferendumsCounterViewModel(
            currentReferendumId: currentReferendumId,
            referendums: referendums
        ) else {
            return
        }

        view?.updateCardsCounter(with: viewModel)
    }
}
