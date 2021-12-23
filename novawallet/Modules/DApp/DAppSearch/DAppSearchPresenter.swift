import Foundation

final class DAppSearchPresenter {
    weak var view: DAppSearchViewProtocol?
    let wireframe: DAppSearchWireframeProtocol
    let interactor: DAppSearchInteractorInputProtocol

    init(
        interactor: DAppSearchInteractorInputProtocol,
        wireframe: DAppSearchWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension DAppSearchPresenter: DAppSearchPresenterProtocol {
    func setup() {}

    func activateBrowser(for input: String) {
        wireframe.showBrowser(from: view, input: input)
    }
}

extension DAppSearchPresenter: DAppSearchInteractorOutputProtocol {}
