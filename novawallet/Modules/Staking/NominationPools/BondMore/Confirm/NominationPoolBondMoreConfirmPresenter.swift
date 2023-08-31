import Foundation

final class NominationPoolBondMoreConfirmPresenter {
    weak var view: NominationPoolBondMoreConfirmViewProtocol?
    let wireframe: NominationPoolBondMoreConfirmWireframeProtocol
    let interactor: NominationPoolBondMoreConfirmInteractorInputProtocol

    init(
        interactor: NominationPoolBondMoreConfirmInteractorInputProtocol,
        wireframe: NominationPoolBondMoreConfirmWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension NominationPoolBondMoreConfirmPresenter: NominationPoolBondMoreConfirmPresenterProtocol {
    func setup() {}
    func proceed() {}
    func selectAccount() {}
}

extension NominationPoolBondMoreConfirmPresenter: NominationPoolBondMoreConfirmInteractorOutputProtocol {}
