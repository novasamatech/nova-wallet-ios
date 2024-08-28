import Foundation

final class PayCardPresenter {
    weak var view: PayCardViewProtocol?
    let wireframe: PayCardWireframeProtocol
    let interactor: PayCardInteractorInputProtocol

    init(
        interactor: PayCardInteractorInputProtocol,
        wireframe: PayCardWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension PayCardPresenter: PayCardPresenterProtocol {
    func setup() {}

    func processTransferData(data: Data) {
        interactor.process(data)
    }

    func processWidgetState(data _: Data) {
        // TODO: Implement when design will be ready
    }
}

extension PayCardPresenter: PayCardInteractorOutputProtocol {
    func didReceive(_ transferModel: MercuryoTransferModel) {
        wireframe.showSend(
            from: view,
            with: transferModel
        )
    }
}
