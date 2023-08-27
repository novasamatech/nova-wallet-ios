import Foundation

final class NPoolsUnstakeSetupPresenter {
    weak var view: NPoolsUnstakeSetupViewProtocol?
    let wireframe: NPoolsUnstakeSetupWireframeProtocol
    let interactor: NPoolsUnstakeSetupInteractorInputProtocol

    init(
        interactor: NPoolsUnstakeSetupInteractorInputProtocol,
        wireframe: NPoolsUnstakeSetupWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension NPoolsUnstakeSetupPresenter: NPoolsUnstakeSetupPresenterProtocol {
    func setup() {}
}

extension NPoolsUnstakeSetupPresenter: NPoolsUnstakeSetupInteractorOutputProtocol {}
