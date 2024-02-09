protocol NotificationsViewProtocol: ControllerBackedProtocol {}

protocol NotificationsPresenterProtocol: AnyObject {
    func setup()
}

protocol NotificationsInteractorInputProtocol: AnyObject {}

protocol NotificationsInteractorOutputProtocol: AnyObject {}

protocol NotificationsWireframeProtocol: AnyObject {}
