import Foundation

final class TinderGovViewModel {
    let wireframe: TinderGovWireframeProtocol

    private weak var view: TinderGovViewProtocol?

    private let referendums: [ReferendumLocal]
    private let viewModelFactory: TinderGovViewModelFactoryProtocol
    private var votingList: [ReferendumIdLocal] = []

    init(
        wireframe: TinderGovWireframeProtocol,
        viewModelFactory: TinderGovViewModelFactoryProtocol,
        referendums: [ReferendumLocal]
    ) {
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.referendums = referendums
    }
}

extension TinderGovViewModel: TinderGovViewModelProtocol {
    func bind(with view: TinderGovViewProtocol) {
        guard let firstReferendum = referendums.first else {
            return
        }

        self.view = view

        updateCardsStackView()
        updateVotingListView()
        updateReferendumsCounter(currentReferendumId: firstReferendum.index)
    }

    func actionBack() {
        wireframe.back(from: view)
    }
}

// MARK: - Private

private extension TinderGovViewModel {
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
