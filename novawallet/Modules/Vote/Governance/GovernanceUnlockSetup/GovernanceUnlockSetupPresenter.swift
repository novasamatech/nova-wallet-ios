import Foundation

final class GovernanceUnlockSetupPresenter {
    weak var view: GovernanceUnlockSetupViewProtocol?
    let wireframe: GovernanceUnlockSetupWireframeProtocol
    let interactor: GovernanceUnlockSetupInteractorInputProtocol

    init(
        interactor: GovernanceUnlockSetupInteractorInputProtocol,
        wireframe: GovernanceUnlockSetupWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension GovernanceUnlockSetupPresenter: GovernanceUnlockSetupPresenterProtocol {
    func setup() {}
}

extension GovernanceUnlockSetupPresenter: GovernanceUnlockSetupInteractorOutputProtocol {}