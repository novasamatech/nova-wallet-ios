import UIKit
import RobinHood

protocol GovernanceNotificationsViewProtocol: ControllerBackedProtocol {
    func didReceive(isClearActionAvailabe: Bool)
    func didReceive(viewModels: [GovernanceNotificationsModel])
    func didReceiveUpdates(for viewModel: GovernanceNotificationsModel)
}

protocol GovernanceNotificationsPresenterProtocol: ChainNotificationSettingsPresenterProtocol {
    func changeSettings(network: ChainModel.Id, isEnabled: Bool)
    func changeSettings(network: ChainModel.Id, newReferendum: Bool)
    func changeSettings(network: ChainModel.Id, referendumUpdate: Bool)
    func changeSettings(network: ChainModel.Id, delegateHasVoted: Bool)
    func selectTracks(network: ChainModel.Id)
    func proceed()
}

protocol GovernanceNotificationsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol GovernanceNotificationsInteractorOutputProtocol: AnyObject {
    func didReceiveChainModel(changes: [DataProviderChange<ChainModel>])
}

protocol GovernanceNotificationsWireframeProtocol: AnyObject {
    func showTracks(
        from view: ControllerBackedProtocol?,
        for chain: ChainModel,
        selectedTracks: Set<TrackIdLocal>?,
        completion: @escaping SelectTracksClosure
    )
    func complete(settings: [ChainModel.Id: GovernanceNotificationsModel])
}
