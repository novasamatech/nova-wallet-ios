import Foundation

final class RampPresenter {
    weak var view: RampViewProtocol?
    var wireframe: RampWireframeProtocol!
    var interactor: RampInteractorInputProtocol!

    let chainAsset: ChainAsset
    let rampAction: RampAction

    let analyticsContent: AnalyticsRampContent?
    var didTrackCompletion: Bool = false

    init(
        wireframe: RampWireframeProtocol!,
        interactor: RampInteractorInputProtocol!,
        chainAsset: ChainAsset,
        rampAction: RampAction
    ) {
        self.wireframe = wireframe
        self.interactor = interactor
        self.chainAsset = chainAsset
        self.rampAction = rampAction

        analyticsContent = AnalyticsRampContent(
            providerId: rampAction.providerId,
            chainAsset: chainAsset
        )
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
        trackFlowOpened()

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
        trackFlowCompleted(for: action.type)

        wireframe.complete(
            from: view,
            with: action.type,
            for: chainAsset
        )
    }
}
