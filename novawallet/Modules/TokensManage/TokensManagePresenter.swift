import Foundation

final class TokensManagePresenter {
    weak var view: TokensManageViewProtocol?
    let wireframe: TokensManageWireframeProtocol
    let interactor: TokensManageInteractorInputProtocol

    init(
        interactor: TokensManageInteractorInputProtocol,
        wireframe: TokensManageWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension TokensManagePresenter: TokensManagePresenterProtocol {
    func setup() {}

    func performAddToken() {}

    func performEdit(for _: TokensManageViewModel) {}

    func performSwitch(for _: TokensManageViewModel, isOn _: Bool) {}
}

extension TokensManagePresenter: TokensManageInteractorOutputProtocol {}
