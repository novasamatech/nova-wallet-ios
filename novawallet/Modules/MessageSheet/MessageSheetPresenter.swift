import Foundation

final class MessageSheetPresenter {
    weak var view: MessageSheetViewProtocol?
    let wireframe: MessageSheetWireframeProtocol

    init(wireframe: MessageSheetWireframeProtocol) {
        self.wireframe = wireframe
    }
}

extension MessageSheetPresenter: MessageSheetPresenterProtocol {
    func goBack() {
        wireframe.complete(on: view)
    }
}

extension MessageSheetPresenter: MessageSheetInteractorOutputProtocol {}
