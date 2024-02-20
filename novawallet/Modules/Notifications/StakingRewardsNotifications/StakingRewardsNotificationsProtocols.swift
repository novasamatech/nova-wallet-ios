import UIKit
import RobinHood

protocol StakingRewardsNotificationsViewProtocol: ControllerBackedProtocol {
    func didReceive(isClearActionAvailabe: Bool)
    func didReceive(viewModels: [StakingRewardsNotificationsViewModel])
}

protocol StakingRewardsNotificationsPresenterProtocol: ChainNotificationSettingsPresenterProtocol {
    func changeSettings(network: ChainModel.Id, isEnabled: Bool)
    func proceed()
}

protocol StakingRewardsNotificationsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol StakingRewardsNotificationsInteractorOutputProtocol: AnyObject {
    func didReceiveChainModel(changes: [DataProviderChange<ChainModel>])
}

protocol StakingRewardsNotificationsWireframeProtocol: AnyObject {
    func complete(selectedChains: Set<ChainModel.Id>, totalChainsCount: Int)
}

struct StakingRewardsNotificationsViewModel {
    let identifier: ChainModel.Id
    let icon: ImageViewModelProtocol?
    let name: String
    let enabled: Bool
}
