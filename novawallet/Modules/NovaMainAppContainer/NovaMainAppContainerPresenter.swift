import Foundation

final class NovaMainAppContainerPresenter {
    weak var view: NovaMainAppContainerViewProtocol?
    let wireframe: NovaMainAppContainerWireframeProtocol
    let interactor: NovaMainAppContainerInteractorInputProtocol

    init(
        interactor: NovaMainAppContainerInteractorInputProtocol,
        wireframe: NovaMainAppContainerWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension NovaMainAppContainerPresenter: NovaMainAppContainerPresenterProtocol {
    func setup() {}
}

extension NovaMainAppContainerPresenter: NovaMainAppContainerInteractorOutputProtocol {}
