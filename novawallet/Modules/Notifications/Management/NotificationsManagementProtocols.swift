protocol NotificationsManagementViewProtocol: ControllerBackedProtocol {
    func didReceive(sections: [(NotificationsManagementSection, [NotificationsManagementCellModel])])
    func didReceive(isSaveActionAvailabe: Bool)
    func startLoading()
    func stopLoading()
}

protocol NotificationsManagementPresenterProtocol: AnyObject {
    func setup()
    func actionRow(_ row: NotificationsManagementRow)
    func save()
    func viewWillAppear()
}

protocol NotificationsManagementInteractorInputProtocol: AnyObject {
    func setup()
    func enableNotifications()
    func save(
        settings: LocalPushSettings,
        notificationsEnabled: Bool,
        announcementsEnabled: Bool
    )
    func remakeSubscription()
    func checkNotificationsStatus()
}

protocol NotificationsManagementInteractorOutputProtocol: AnyObject {
    func didReceive(settings: LocalPushSettings)
    func didReceive(error: NotificationsManagementError)
    func didReceive(notificationsEnabled: Bool)
    func didReceive(announcementsEnabled: Bool)
    func didReceiveSaveCompletion()
}

protocol NotificationsManagementWireframeProtocol: AnyObject, AlertPresentable, ErrorPresentable,
    ApplicationSettingsPresentable, CommonRetryable {
    func showWallets(from view: ControllerBackedProtocol?)
    func showStakingRewardsSetup(from view: ControllerBackedProtocol?)
    func showGovSetup(from view: ControllerBackedProtocol?)
    func complete(from view: ControllerBackedProtocol?)
}

enum NotificationsManagementError: Error {
    case settingsSubscription(Error)
    case notificationsDisabledInSettings
}

typealias NotificationsManagementCellModel = CommonSettingsCellViewModel<NotificationsManagementRow>
