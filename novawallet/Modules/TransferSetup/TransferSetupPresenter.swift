import Foundation

final class TransferSetupPresenter {
    weak var view: TransferSetupViewProtocol?
    let wireframe: TransferSetupWireframeProtocol
    let interactor: TransferSetupInteractorInputProtocol

    init(
        interactor: TransferSetupInteractorInputProtocol,
        wireframe: TransferSetupWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension TransferSetupPresenter: TransferSetupPresenterProtocol {
    func setup() {}
}

extension TransferSetupPresenter: TransferSetupInteractorOutputProtocol {}
