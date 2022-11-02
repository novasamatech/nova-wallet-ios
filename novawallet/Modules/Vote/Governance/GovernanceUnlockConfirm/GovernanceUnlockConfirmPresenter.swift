import Foundation

final class GovernanceUnlockConfirmPresenter {
    weak var view: GovernanceUnlockConfirmViewProtocol?
    let wireframe: GovernanceUnlockConfirmWireframeProtocol
    let interactor: GovernanceUnlockConfirmInteractorInputProtocol

    init(
        interactor: GovernanceUnlockConfirmInteractorInputProtocol,
        wireframe: GovernanceUnlockConfirmWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension GovernanceUnlockConfirmPresenter: GovernanceUnlockConfirmPresenterProtocol {
    func setup() {}
}

extension GovernanceUnlockConfirmPresenter: GovernanceUnlockConfirmInteractorOutputProtocol {}