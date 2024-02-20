import UIKit
import RobinHood

protocol GovernanceNotificationsViewProtocol: ControllerBackedProtocol {
    func didReceive(isClearActionAvailabe: Bool)
    func didReceive(viewModels: [GovernanceNotificationsModel])
    func didReceiveUpdates(for viewModel: GovernanceNotificationsModel)
}

protocol GovernanceNotificationsPresenterProtocol: ChainNotificationSettingsPresenterProtocol {
    func changeSettings(chainId: ChainModel.Id, isEnabled: Bool)
    func changeSettings(chainId: ChainModel.Id, newReferendum: Bool)
    func changeSettings(chainId: ChainModel.Id, referendumUpdate: Bool)
    func changeSettings(chainId: ChainModel.Id, delegateHasVoted: Bool)
    func selectTracks(chainId: ChainModel.Id)
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
