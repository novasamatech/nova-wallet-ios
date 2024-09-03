protocol TinderGovViewProtocol: ControllerBackedProtocol {}

protocol TinderGovViewModelProtocol: AnyObject {
    func bind()
    func actionBack()
    func getCardsModel() -> [VoteCardViewModel]
}

protocol TinderGovInteractorInputProtocol: AnyObject {}

protocol TinderGovInteractorOutputProtocol: AnyObject {}

protocol TinderGovWireframeProtocol: AnyObject {
    func back(from view: ControllerBackedProtocol?)
}
