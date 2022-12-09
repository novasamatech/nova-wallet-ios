import Foundation

final class TokensManageAddPresenter {
    weak var view: TokensManageAddViewProtocol?
    let wireframe: TokensManageAddWireframeProtocol
    let interactor: TokensManageAddInteractorInputProtocol

    init(
        interactor: TokensManageAddInteractorInputProtocol,
        wireframe: TokensManageAddWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension TokensManageAddPresenter: TokensManageAddPresenterProtocol {
    func setup() {}
}

extension TokensManageAddPresenter: TokensManageAddInteractorOutputProtocol {}
