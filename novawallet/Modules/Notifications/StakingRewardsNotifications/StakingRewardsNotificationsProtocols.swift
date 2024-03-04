import UIKit
import RobinHood

protocol StakingRewardsNotificationsViewProtocol: ControllerBackedProtocol {
    func didReceive(isClearActionAvailabe: Bool)
    func didReceive(viewModels: [StakingRewardsNotificationsViewModel])
}

protocol StakingRewardsNotificationsPresenterProtocol: ChainNotificationSettingsPresenterProtocol {
    func changeSettings(chainId: ChainModel.Id, isEnabled: Bool)
    func proceed()
}

protocol StakingRewardsNotificationsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol StakingRewardsNotificationsInteractorOutputProtocol: AnyObject {
    func didReceiveChainModel(changes: [DataProviderChange<ChainModel>])
}

protocol StakingRewardsNotificationsWireframeProtocol: AnyObject {
    func complete(selectedChains: Web3Alert.Selection<Set<ChainModel.Id>>?)
}

struct StakingRewardsNotificationsViewModel {
    let identifier: ChainModel.Id
    let icon: ImageViewModelProtocol?
    let name: String
    let enabled: Bool
}
