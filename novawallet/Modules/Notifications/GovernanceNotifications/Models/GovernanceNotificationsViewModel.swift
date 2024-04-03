import Foundation
import RobinHood

struct GovernanceNotificationsViewModel: Identifiable {
    struct SelectedTracks {
        let tracks: Set<TrackIdLocal>
        let totalTracksCount: Int

        var allSelected: Bool {
            tracks.count == totalTracksCount
        }
    }

    let identifier: ChainModel.Id
    let enabled: Bool
    let icon: ImageViewModelProtocol?
    let name: String
    let newReferendum: Bool
    let referendumUpdate: Bool
    let selectedTracks: SelectedTracks

    var allNotificationsIsOff: Bool {
        newReferendum == false && referendumUpdate == false
    }
}
