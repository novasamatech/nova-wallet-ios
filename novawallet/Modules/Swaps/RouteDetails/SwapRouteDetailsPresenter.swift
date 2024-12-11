import Foundation

final class SwapRouteDetailsPresenter {
    weak var view: SwapRouteDetailsViewProtocol?
    let wireframe: SwapRouteDetailsWireframeProtocol
    let interactor: SwapRouteDetailsInteractorInputProtocol

    init(
        interactor: SwapRouteDetailsInteractorInputProtocol,
        wireframe: SwapRouteDetailsWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension SwapRouteDetailsPresenter: SwapRouteDetailsPresenterProtocol {
    func setup() {}
}

extension SwapRouteDetailsPresenter: SwapRouteDetailsInteractorOutputProtocol {}
