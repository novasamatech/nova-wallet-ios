import Foundation

final class TinderGovPresenter {
    weak var view: TinderGovViewProtocol?
    let wireframe: TinderGovWireframeProtocol
    let interactor: TinderGovInteractorInputProtocol

    init(
        interactor: TinderGovInteractorInputProtocol,
        wireframe: TinderGovWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension TinderGovPresenter: TinderGovPresenterProtocol {
    func setup() {}
}

extension TinderGovPresenter: TinderGovInteractorOutputProtocol {}
