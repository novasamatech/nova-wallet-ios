import Foundation

final class MessageSheetPresenter {
    weak var view: MessageSheetViewProtocol?
    let wireframe: MessageSheetWireframeProtocol

    init(wireframe: MessageSheetWireframeProtocol) {
        self.wireframe = wireframe
    }
}

extension MessageSheetPresenter: MessageSheetPresenterProtocol {
    func goBack(with action: MessageSheetAction?) {
        wireframe.complete(on: view, with: action)
    }
}

extension MessageSheetPresenter: MessageSheetInteractorOutputProtocol {}
