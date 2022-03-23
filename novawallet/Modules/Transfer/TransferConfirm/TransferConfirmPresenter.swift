import Foundation

final class TransferConfirmPresenter {
    weak var view: TransferConfirmViewProtocol?
    let wireframe: TransferConfirmWireframeProtocol
    let interactor: TransferConfirmInteractorInputProtocol

    let recepient: AccountAddress
    let amount: Decimal

    init(
        interactor: TransferConfirmInteractorInputProtocol,
        wireframe: TransferConfirmWireframeProtocol,
        recepient: AccountAddress,
        amount: Decimal
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.recepient = recepient
        self.amount = amount
    }
}

extension TransferConfirmPresenter: TransferConfirmPresenterProtocol {
    func setup() {}
}

extension TransferConfirmPresenter: TransferConfirmInteractorOutputProtocol {}
