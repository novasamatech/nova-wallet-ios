import UIKit

protocol StakingRewardsNotificationsViewProtocol: ControllerBackedProtocol {
    func didReceive(isClearActionAvailabe: Bool)
    func didReceive(viewModels: [StakingRewardsNotificationsViewModel])
}

protocol StakingRewardsNotificationsPresenterProtocol: ChainNotificationSettingsPresenterProtocol {
    func changeSettings(network: String, isEnabled: Bool)
}

protocol StakingRewardsNotificationsInteractorInputProtocol: AnyObject {}

protocol StakingRewardsNotificationsInteractorOutputProtocol: AnyObject {}

protocol StakingRewardsNotificationsWireframeProtocol: AnyObject {}

struct StakingRewardsNotificationsViewModel {
    let icon: UIImage?
    let name: String
    let enabled: Bool
}
