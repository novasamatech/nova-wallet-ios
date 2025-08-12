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
    func back()
}

protocol NotificationsManagementInteractorInputProtocol: AnyObject {
    func setup()
    func save(
        settings: Web3Alert.LocalSettings,
        topics: PushNotification.TopicSettings,
        notificationsEnabled: Bool
    )
    func remakeSubscription()
}

protocol NotificationsManagementInteractorOutputProtocol: AnyObject {
    func didReceive(settings: Web3Alert.LocalSettings)
    func didReceive(topicsSettings: PushNotification.TopicSettings)
    func didReceive(error: NotificationsManagementError)
    func didReceive(notificationStatus: PushNotificationsStatus)
    func didReceiveSaveCompletion()
}

protocol NotificationsManagementWireframeProtocol: AnyObject, AlertPresentable, ErrorPresentable,
    ApplicationSettingsPresentable, CommonRetryable {
    func showWallets(
        from view: ControllerBackedProtocol?,
        initState: [Web3Alert.LocalWallet]?,
        completion: @escaping ([Web3Alert.LocalWallet]) -> Void
    )

    func showStakingRewardsSetup(
        from view: ControllerBackedProtocol?,
        selectedChains: Web3Alert.Selection<Set<Web3Alert.LocalChainId>>?,
        completion: @escaping (Web3Alert.Selection<Set<Web3Alert.LocalChainId>>?) -> Void
    )

    func showGovSetup(
        from view: ControllerBackedProtocol?,
        settings: GovernanceNotificationsModel,
        completion: @escaping (GovernanceNotificationsModel) -> Void
    )

    func showMultisigSetup(
        from view: ControllerBackedProtocol?,
        settings: MultisigNotificationsModel,
        completion: @escaping (MultisigNotificationsModel) -> Void
    )

    func complete(from view: ControllerBackedProtocol?)

    func saved(on view: ControllerBackedProtocol?)
}

enum NotificationsManagementError: Error {
    case settingsSubscription(Error)
    case save(Error)
}

typealias NotificationsManagementCellModel = CommonSettingsCellViewModel<NotificationsManagementRow>
