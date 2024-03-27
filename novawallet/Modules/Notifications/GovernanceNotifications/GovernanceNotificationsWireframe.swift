import Foundation

final class GovernanceNotificationsWireframe: GovernanceNotificationsWireframeProtocol {
    let completion: (GovernanceNotificationsModel) -> Void

    init(completion: @escaping (GovernanceNotificationsModel) -> Void) {
        self.completion = completion
    }

    func showTracks(
        from view: ControllerBackedProtocol?,
        for chain: ChainModel,
        selectedTracks: Set<TrackIdLocal>?,
        completion: @escaping SelectTracksClosure
    ) {
        guard let tracksSettingsView = GovernanceTracksSettingsViewFactory.createView(
            selectedTracks: selectedTracks,
            chain: chain,
            completion: completion
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            tracksSettingsView.controller,
            animated: true
        )
    }

    func complete(settings: GovernanceNotificationsModel) {
        completion(settings)
    }
}
