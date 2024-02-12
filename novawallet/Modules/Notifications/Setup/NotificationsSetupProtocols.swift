protocol NotificationsSetupViewProtocol: ControllerBackedProtocol {}

protocol NotificationsSetupPresenterProtocol: AnyObject {
    func setup()
    func enablePushNotifications()
    func skip()
    func activateTerms()
    func activatePrivacy()
}

protocol NotificationsSetupInteractorInputProtocol: AnyObject {
    func enablePushNotifications()
}

protocol NotificationsSetupInteractorOutputProtocol: AnyObject {}

protocol NotificationsSetupWireframeProtocol: WebPresentable {
    func complete(on view: ControllerBackedProtocol?)
}
