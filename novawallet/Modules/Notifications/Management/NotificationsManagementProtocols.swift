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
}

protocol NotificationsManagementInteractorInputProtocol: AnyObject {
    func setup()
    func checkNotificationsAvailability()
    func save(
        settings: LocalPushSettings,
        topics: LocalNotificationTopicSettings,
        notificationsEnabled: Bool,
        announcementsEnabled: Bool
    )
    func remakeSubscription()
}

protocol NotificationsManagementInteractorOutputProtocol: AnyObject {
    func didReceive(settings: LocalPushSettings)
    func didReceive(topicsSettings: LocalNotificationTopicSettings)
    func didReceive(error: NotificationsManagementError)
    func didReceive(notificationsEnabled: Bool)
    func didReceive(announcementsEnabled: Bool)
    func didReceiveSaveCompletion()
}

protocol NotificationsManagementWireframeProtocol: AnyObject, AlertPresentable, ErrorPresentable,
    ApplicationSettingsPresentable, CommonRetryable {
    func showWallets(
        from view: ControllerBackedProtocol?,
        initState: [Web3AlertWallet]?,
        completion: @escaping ([Web3AlertWallet]) -> Void
    )
    func showStakingRewardsSetup(
        from view: ControllerBackedProtocol?,
        selectedChains: Selection<Set<ChainModel.Id>>?,
        completion: @escaping (Selection<Set<ChainModel.Id>>?) -> Void
    )
    func showGovSetup(
        from view: ControllerBackedProtocol?,
        settings: GovernanceNotificationsInitModel?,
        completion: @escaping ([ChainModel.Id: GovernanceNotificationsModel]) -> Void
    )
    func complete(from view: ControllerBackedProtocol?)
}

enum NotificationsManagementError: Error {
    case settingsSubscription(Error)
    case notificationsDisabledInSettings
    case save(Error)
}

typealias NotificationsManagementCellModel = CommonSettingsCellViewModel<NotificationsManagementRow>
