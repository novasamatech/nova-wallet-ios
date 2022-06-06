import Foundation

final class ParaStkRebondPresenter {
    weak var view: ParaStkRebondViewProtocol?
    let wireframe: ParaStkRebondWireframeProtocol
    let interactor: ParaStkRebondInteractorInputProtocol

    init(
        interactor: ParaStkRebondInteractorInputProtocol,
        wireframe: ParaStkRebondWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension ParaStkRebondPresenter: ParaStkRebondPresenterProtocol {
    func setup() {}
}

extension ParaStkRebondPresenter: ParaStkRebondInteractorOutputProtocol {}
