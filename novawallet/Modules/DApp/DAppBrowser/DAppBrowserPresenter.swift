import Foundation

final class DAppBrowserPresenter {
    weak var view: DAppBrowserViewProtocol?
    let wireframe: DAppBrowserWireframeProtocol
    let interactor: DAppBrowserInteractorInputProtocol

    init(
        interactor: DAppBrowserInteractorInputProtocol,
        wireframe: DAppBrowserWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension DAppBrowserPresenter: DAppBrowserPresenterProtocol {
    func setup() {}
}

extension DAppBrowserPresenter: DAppBrowserInteractorOutputProtocol {}
