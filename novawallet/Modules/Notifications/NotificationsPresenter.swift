import Foundation

final class NotificationsPresenter {
    weak var view: NotificationsViewProtocol?
    let wireframe: NotificationsWireframeProtocol
    let interactor: NotificationsInteractorInputProtocol

    init(
        interactor: NotificationsInteractorInputProtocol,
        wireframe: NotificationsWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension NotificationsPresenter: NotificationsPresenterProtocol {
    func setup() {}
}

extension NotificationsPresenter: NotificationsInteractorOutputProtocol {}