import Foundation

struct NotificationsViewFactory {
    static func createView(settings: LocalPushSettings?) -> NotificationsViewProtocol? {
        let interactor = NotificationsInteractor()
        let wireframe = NotificationsWireframe()

        let presenter = NotificationsPresenter(interactor: interactor, wireframe: wireframe)

        let view = NotificationsViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
