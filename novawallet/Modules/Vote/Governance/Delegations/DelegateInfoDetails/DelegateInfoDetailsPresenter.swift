import Foundation

final class DelegateInfoDetailsPresenter {
    weak var view: DelegateInfoDetailsViewProtocol?
    let wireframe: DelegateInfoDetailsWireframeProtocol
    let interactor: DelegateInfoDetailsInteractorInputProtocol

    init(
        interactor: DelegateInfoDetailsInteractorInputProtocol,
        wireframe: DelegateInfoDetailsWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension DelegateInfoDetailsPresenter: DelegateInfoDetailsPresenterProtocol {
    func setup() {}
}

extension DelegateInfoDetailsPresenter: DelegateInfoDetailsInteractorOutputProtocol {}