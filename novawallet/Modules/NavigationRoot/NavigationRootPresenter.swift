import Foundation

final class NavigationRootPresenter {
    weak var view: NavigationRootViewProtocol?
    let wireframe: NavigationRootWireframeProtocol
    let interactor: NavigationRootInteractorInputProtocol

    init(
        interactor: NavigationRootInteractorInputProtocol,
        wireframe: NavigationRootWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension NavigationRootPresenter: NavigationRootPresenterProtocol {
    func setup() {}
}

extension NavigationRootPresenter: NavigationRootInteractorOutputProtocol {}
