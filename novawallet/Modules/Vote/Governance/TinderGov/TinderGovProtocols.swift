import Operation_iOS

protocol TinderGovViewProtocol: ControllerBackedProtocol {
    func updateCards(with newModels: [VoteCardViewModel])
    func skipCard()
    func updateVotingList(with viewModel: VotingListWidgetViewModel)
    func updateCardsCounter(with text: String)
}

protocol TinderGovPresenterProtocol: AnyObject {
    func setup()
    func actionBack()
}

protocol TinderGovInteractorInputProtocol: AnyObject {
    func setup()
}

protocol TinderGovInteractorOutputProtocol: AnyObject {
    func didReceive(_ changes: [DataProviderChange<ReferendumLocal>])
}

protocol TinderGovWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable {
    func back(from view: ControllerBackedProtocol?)
}
