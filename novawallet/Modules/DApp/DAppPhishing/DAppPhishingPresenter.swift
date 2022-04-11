import Foundation

final class DAppPhishingPresenter {
    weak var view: DAppPhishingViewProtocol?
    let wireframe: DAppPhishingWireframeProtocol

    init(wireframe: DAppPhishingWireframeProtocol) {
        self.wireframe = wireframe
    }
}

extension DAppPhishingPresenter: DAppPhishingPresenterProtocol {
    func setup() {}

    func goBack() {
        wireframe.complete(from: view)
    }
}
