import Foundation

final class ParaStkSelectCollatorsPresenter {
    weak var view: ParaStkSelectCollatorsViewProtocol?
    let wireframe: ParaStkSelectCollatorsWireframeProtocol
    let interactor: ParaStkSelectCollatorsInteractorInputProtocol

    init(
        interactor: ParaStkSelectCollatorsInteractorInputProtocol,
        wireframe: ParaStkSelectCollatorsWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension ParaStkSelectCollatorsPresenter: ParaStkSelectCollatorsPresenterProtocol {
    func setup() {}
}

extension ParaStkSelectCollatorsPresenter: ParaStkSelectCollatorsInteractorOutputProtocol {}
