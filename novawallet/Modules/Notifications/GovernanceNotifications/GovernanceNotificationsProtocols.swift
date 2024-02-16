import UIKit

protocol GovernanceNotificationsViewProtocol: ControllerBackedProtocol {
    func didReceive(isClearActionAvailabe: Bool)
    func didReceive(viewModel: GovernanceNotificationsViewModel)
}

protocol GovernanceNotificationsPresenterProtocol: ChainNotificationSettingsPresenterProtocol {
    func changeSettings(network: String, isEnabled: Bool)
    func changeSettings(network: String, new: Bool)
    func changeSettings(network: String, update: Bool)
    func changeSettings(network: String, delegate: Bool)
    func selectTracks(network: String)
}

protocol GovernanceNotificationsInteractorInputProtocol: AnyObject {}

protocol GovernanceNotificationsInteractorOutputProtocol: AnyObject {}

protocol GovernanceNotificationsWireframeProtocol: AnyObject {}

struct GovernanceNotificationsViewModel {
    let extendedSettings: [ExtendedNetworkSettings]
    let settings: [NetworkSettings]

    struct ExtendedNetworkSettings {
        let icon: UIImage?
        let name: String
        let settings: RichSettings
        let enabled: Bool
    }

    struct RichSettings {
        let new: Bool
        let update: Bool
        let delegate: Bool
        let tracks: String
    }

    struct NetworkSettings {
        let icon: UIImage?
        let name: String
        let enabled: Bool
    }
}
