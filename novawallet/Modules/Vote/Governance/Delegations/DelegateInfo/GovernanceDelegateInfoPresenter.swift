import Foundation

final class GovernanceDelegateInfoPresenter {
    weak var view: GovernanceDelegateInfoViewProtocol?
    let wireframe: GovernanceDelegateInfoWireframeProtocol
    let interactor: GovernanceDelegateInfoInteractorInputProtocol

    init(
        interactor: GovernanceDelegateInfoInteractorInputProtocol,
        wireframe: GovernanceDelegateInfoWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension GovernanceDelegateInfoPresenter: GovernanceDelegateInfoPresenterProtocol {
    func setup() {}
}

extension GovernanceDelegateInfoPresenter: GovernanceDelegateInfoInteractorOutputProtocol {}
