protocol NotificationsSetupViewProtocol: ControllerBackedProtocol {}

protocol NotificationsSetupPresenterProtocol: AnyObject {
    func setup()
    func enablePushNotifications()
    func skip()
    func activateTerms()
    func activatePrivacy()
}

protocol NotificationsSetupInteractorInputProtocol: AnyObject {
    func setup()
    func enablePushNotifications()
}

protocol NotificationsSetupInteractorOutputProtocol: AnyObject {
    func didRegister(notificationStatus: PushNotificationsStatus)
}

protocol NotificationsSetupWireframeProtocol: WebPresentable {
    func complete(on view: ControllerBackedProtocol?)
}
