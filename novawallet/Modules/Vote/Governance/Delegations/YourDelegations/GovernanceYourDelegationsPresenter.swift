import Foundation

final class GovernanceYourDelegationsPresenter {
    weak var view: GovernanceYourDelegationsViewProtocol?
    let wireframe: GovernanceYourDelegationsWireframeProtocol
    let interactor: GovernanceYourDelegationsInteractorInputProtocol

    init(
        interactor: GovernanceYourDelegationsInteractorInputProtocol,
        wireframe: GovernanceYourDelegationsWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension GovernanceYourDelegationsPresenter: GovernanceYourDelegationsPresenterProtocol {
    func setup() {}
}

extension GovernanceYourDelegationsPresenter: GovernanceYourDelegationsInteractorOutputProtocol {
    func didReceiveDelegations(_: [TrackIdLocal: ReferendumDelegatingLocal]) {}

    func didReceiveDelegates(_: [GovernanceDelegateLocal]) {}

    func didReceiveTracks(_: [GovernanceTrackInfoLocal]) {}

    func didReceiveError(_: GovernanceYourDelegationsInteractorError) {}
}
