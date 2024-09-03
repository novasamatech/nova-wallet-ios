import Foundation

final class TinderGovViewModel {
    let wireframe: TinderGovWireframeProtocol

    private weak var view: TinderGovViewProtocol?

    private let referendums: [ReferendumLocal]
    private let viewModelFactory: TinderGovViewModelFactoryProtocol

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
        self.view = view

        let cardViewModels = viewModelFactory.createVoteCardViewModels(from: referendums)

        view.updateCards(with: cardViewModels)
        view.updateVotingList()
    }

    func actionBack() {
        wireframe.back(from: view)
    }
}
