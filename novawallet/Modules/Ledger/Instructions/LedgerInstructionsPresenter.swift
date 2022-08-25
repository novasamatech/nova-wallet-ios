import Foundation

final class LedgerInstructionsPresenter {
    weak var view: LedgerInstructionsViewProtocol?
    let wireframe: LedgerInstructionsWireframeProtocol

    init(wireframe: LedgerInstructionsWireframeProtocol) {
        self.wireframe = wireframe
    }
}

extension LedgerInstructionsPresenter: LedgerInstructionsPresenterProtocol {
    func showHint() {

    }
    
    func proceed() {

    }
}
