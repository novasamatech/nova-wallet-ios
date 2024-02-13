protocol NotificationsManagementViewProtocol: ControllerBackedProtocol {
    func didReceive(sections: [(NotificationsManagementSection, [CommonSettingsCellViewModel<NotificationsManagementRow>])])
    func didReceive(isSaveActionAvailabe: Bool)
}

protocol NotificationsManagementPresenterProtocol: AnyObject {
    func setup()
    func actionRow(_ row: NotificationsManagementRow)
    func save()
}

protocol NotificationsManagementInteractorInputProtocol: AnyObject {}

protocol NotificationsManagementInteractorOutputProtocol: AnyObject {}

protocol NotificationsManagementWireframeProtocol: AnyObject {
    func showWallets(from view: ControllerBackedProtocol?)
    func showStakingRewardsSetup(from view: ControllerBackedProtocol?)
    func showGovSetup(from view: ControllerBackedProtocol?)
}
