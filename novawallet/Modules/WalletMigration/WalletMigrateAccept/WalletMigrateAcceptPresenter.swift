import Foundation

final class WalletMigrateAcceptPresenter {
    weak var view: WalletMigrateAcceptViewProtocol?
    let wireframe: WalletMigrateAcceptWireframeProtocol
    let interactor: WalletMigrateAcceptInteractorInputProtocol

    init(
        interactor: WalletMigrateAcceptInteractorInputProtocol,
        wireframe: WalletMigrateAcceptWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension WalletMigrateAcceptPresenter: WalletMigrateAcceptPresenterProtocol {
    func setup() {}
}

extension WalletMigrateAcceptPresenter: WalletMigrateAcceptInteractorOutputProtocol {}