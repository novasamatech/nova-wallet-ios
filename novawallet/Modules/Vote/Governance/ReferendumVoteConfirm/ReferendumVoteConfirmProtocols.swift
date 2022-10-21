protocol ReferendumVoteConfirmViewProtocol: ControllerBackedProtocol {}

protocol ReferendumVoteConfirmPresenterProtocol: AnyObject {
    func setup()
}

protocol ReferendumVoteConfirmInteractorInputProtocol: ReferendumVoteInteractorInputProtocol {
    func submit(vote: ReferendumVoteAction)
}

protocol ReferendumVoteConfirmInteractorOutputProtocol: AnyObject {}

protocol ReferendumVoteConfirmWireframeProtocol: AnyObject {}
