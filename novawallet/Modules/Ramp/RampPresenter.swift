import Foundation

final class RampPresenter {
    weak var view: RampViewProtocol?
    var wireframe: RampWireframeProtocol!
    var interactor: RampInteractorInputProtocol!

    let chainAsset: ChainAsset
    let action: RampAction

    init(
        wireframe: RampWireframeProtocol!,
        interactor: RampInteractorInputProtocol!,
        chainAsset: ChainAsset,
        action: RampAction
    ) {
        self.wireframe = wireframe
        self.interactor = interactor
        self.chainAsset = chainAsset
        self.action = action
    }
}

// MARK: RampPresenterProtocol

extension RampPresenter: RampPresenterProtocol {
    func processMessage(
        body: Any,
        of name: String
    ) {
        interactor.processMessage(
            body: body,
            of: name
        )
    }

    func setup() {
        interactor.setup()
    }
}

// MARK: RampInteractorOutputProtocol

extension RampPresenter: RampInteractorOutputProtocol {
    func didReceive(model: RampModel) {
        view?.didReceive(model: model)
    }

    func didRequestTransfer(for model: PayCardTopupModel) {
        wireframe.showSend(
            from: view,
            with: model
        )
    }

    func didCompleteOperation(action: RampAction) {
        wireframe.complete(
            from: view,
            with: action.type,
            for: chainAsset
        )
    }
}
