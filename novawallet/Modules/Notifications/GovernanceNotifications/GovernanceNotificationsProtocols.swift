import UIKit
import Operation_iOS

protocol GovernanceNotificationsViewProtocol: ControllerBackedProtocol {
    func didReceive(isClearActionAvailabe: Bool)
    func didReceive(viewModels: [GovernanceNotificationsViewModel])
}

protocol GovernanceNotificationsPresenterProtocol: BaseNotificationSettingsPresenterProtocol {
    func changeSettings(chainId: ChainModel.Id, isEnabled: Bool)
    func changeSettings(chainId: ChainModel.Id, newReferendum: Bool)
    func changeSettings(chainId: ChainModel.Id, referendumUpdate: Bool)
    func selectTracks(chainId: ChainModel.Id)
    func proceed()
}

protocol GovernanceNotificationsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol GovernanceNotificationsInteractorOutputProtocol: AnyObject {
    func didReceiveChainModel(changes: [DataProviderChange<ChainModel>])
    func didReceiveTracks(_ tracks: [GovernanceTrackInfoLocal], for chain: ChainModel)
    func didReceive(trackFetchError: Error, for chain: ChainModel)
}

protocol GovernanceNotificationsWireframeProtocol: AnyObject {
    func showTracks(
        from view: ControllerBackedProtocol?,
        for chain: ChainModel,
        selectedTracks: Set<TrackIdLocal>?,
        completion: @escaping SelectTracksClosure
    )
    func complete(settings: GovernanceNotificationsModel)
}
