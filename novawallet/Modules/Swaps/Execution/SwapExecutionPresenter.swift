import Foundation

final class SwapExecutionPresenter {
    weak var view: SwapExecutionViewProtocol?
    let wireframe: SwapExecutionWireframeProtocol
    let interactor: SwapExecutionInteractorInputProtocol

    init(
        interactor: SwapExecutionInteractorInputProtocol,
        wireframe: SwapExecutionWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension SwapExecutionPresenter: SwapExecutionPresenterProtocol {
    func setup() {}
}

extension SwapExecutionPresenter: SwapExecutionInteractorOutputProtocol {}