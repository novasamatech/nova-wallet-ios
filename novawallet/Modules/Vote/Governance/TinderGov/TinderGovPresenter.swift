import Foundation
import SoraFoundation

final class TinderGovPresenter {
    weak var view: TinderGovViewProtocol?
    let interactor: TinderGovInteractorInputProtocol
    let wireframe: TinderGovWireframeProtocol

    private let viewModelFactory: TinderGovViewModelFactoryProtocol
    private let cardsViewModelFactory: VoteCardViewModelFactoryProtocol

    private var referendums: [ReferendumLocal] = []
    private var votingList: [ReferendumIdLocal] = []

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
}

// MARK: TinderGovInteractorOutputProtocol

extension TinderGovPresenter: TinderGovInteractorOutputProtocol {
    func didReceive(_ referendums: [ReferendumLocal]) {
        self.referendums = referendums

        updateViews()
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

    func updateViews() {
        guard let firstReferendum = referendums.first else {
            return
        }

        updateCardsStackView()
        updateVotingListView()
        updateReferendumsCounter(currentReferendumId: firstReferendum.index)
    }

    func updateCardsStackView() {
        let cardViewModels = cardsViewModelFactory.createVoteCardViewModels(
            from: referendums,
            locale: selectedLocale,
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
                    locale: selectedLocale,
                    retryAction: { handlers.retry() },
                    skipAction: { self.view?.skipCard() }
                )
            }
        )

        view?.updateCards(with: cardViewModels)
    }

    func updateVotingListView() {
        let viewModel = viewModelFactory.createVotingListViewModel(
            from: votingList,
            locale: selectedLocale
        )
        view?.updateVotingList(with: viewModel)
    }

    func updateReferendumsCounter(currentReferendumId: ReferendumIdLocal) {
        guard let viewModel = viewModelFactory.createReferendumsCounterViewModel(
            currentReferendumId: currentReferendumId,
            referendums: referendums,
            locale: selectedLocale
        ) else {
            return
        }

        view?.updateCardsCounter(with: viewModel)
    }
}

// MARK: Localizable

extension TinderGovPresenter: Localizable {
    func applyLocalization() {
        guard view?.isSetup == true else {
            return
        }

        updateViews()
    }
}
