import Foundation

final class SwapConfirmPresenter {
    weak var view: SwapConfirmViewProtocol?
    let wireframe: SwapConfirmWireframeProtocol
    let interactor: SwapConfirmInteractorInputProtocol

    init(
        interactor: SwapConfirmInteractorInputProtocol,
        wireframe: SwapConfirmWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension SwapConfirmPresenter: SwapConfirmPresenterProtocol {
    func setup() {}
}

extension SwapConfirmPresenter: SwapConfirmInteractorOutputProtocol {}
