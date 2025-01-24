import Foundation

final class MythosStakingConfirmPresenter {
    weak var view: CollatorStakingConfirmViewProtocol?
    let wireframe: MythosStakingConfirmWireframeProtocol
    let interactor: MythosStakingConfirmInteractorInputProtocol

    init(
        interactor: MythosStakingConfirmInteractorInputProtocol,
        wireframe: MythosStakingConfirmWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension MythosStakingConfirmPresenter: CollatorStakingConfirmPresenterProtocol {
    func setup() {}
    func selectAccount() {}
    func selectCollator() {}
    func confirm() {}
}

extension MythosStakingConfirmPresenter: MythosStakingConfirmInteractorOutputProtocol {}
