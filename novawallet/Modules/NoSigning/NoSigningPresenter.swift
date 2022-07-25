import Foundation

final class NoSigningPresenter {
    weak var view: NoSigningViewProtocol?
    let wireframe: NoSigningWireframeProtocol

    init(wireframe: NoSigningWireframeProtocol) {
        self.wireframe = wireframe
    }
}

extension NoSigningPresenter: NoSigningPresenterProtocol {
    func goBack() {
        wireframe.complete(on: view)
    }
}

extension NoSigningPresenter: NoSigningInteractorOutputProtocol {}
