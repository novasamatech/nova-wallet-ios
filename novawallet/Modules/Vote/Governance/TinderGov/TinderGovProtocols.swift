import Operation_iOS

protocol TinderGovViewProtocol: ControllerBackedProtocol {
    func updateCardsStack(with changeModel: CardsZStackChangeModel)
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
    func addVoting(for referendumId: ReferendumIdLocal)
}

protocol TinderGovInteractorOutputProtocol: AnyObject {
    func didReceive(_ modelBuilderResult: TinderGovModelBuilder.Result)
}

protocol TinderGovWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable {
    func back(from view: ControllerBackedProtocol?)
}
