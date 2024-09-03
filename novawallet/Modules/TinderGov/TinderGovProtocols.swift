protocol TinderGovViewProtocol: ControllerBackedProtocol {
    func updateCards(with newModels: [VoteCardViewModel])
    func updateVotingList(with viewModel: VotingListWidgetViewModel)
    func updateCardsCounter(with text: String)
}

protocol TinderGovViewModelProtocol: AnyObject {
    func bind(with view: TinderGovViewProtocol)
    func actionBack()
}

protocol TinderGovInteractorInputProtocol: AnyObject {}

protocol TinderGovInteractorOutputProtocol: AnyObject {}

protocol TinderGovWireframeProtocol: AnyObject {
    func back(from view: ControllerBackedProtocol?)
}
