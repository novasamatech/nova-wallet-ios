import RobinHood

struct GovernanceNotificationsModel: Identifiable {
    var identifier: ChainModel.Id
    var enabled: Bool
    var icon: ImageViewModelProtocol?
    var name: String
    var newReferendum: Bool
    var referendumUpdate: Bool
    var tracks: SelectedTracks

    enum SelectedTracks {
        case all
        case concrete(Set<TrackIdLocal>, count: Int?)
    }

    var allNotificationsIsOff: Bool {
        newReferendum == false &&
            referendumUpdate == false
    }
}

extension GovernanceNotificationsModel {
    var selectedTracks: Set<TrackIdLocal>? {
        switch tracks {
        case .all:
            return nil
        case let .concrete(tracksIds, _):
            return Set(tracksIds)
        }
    }

    mutating func set(selectedTracks: Set<TrackIdLocal>, count: Int?) {
        if selectedTracks.count == count {
            tracks = .all
        } else {
            tracks = .concrete(selectedTracks, count: count)
        }
    }
}

struct GovernanceNotificationsInitModel {
    var newReferendum: [ChainModel.Id: Selection<Set<TrackIdLocal>>]
    var referendumUpdate: [ChainModel.Id: Selection<Set<TrackIdLocal>>]

    func tracks(for chainId: ChainModel.Id) -> Selection<Set<TrackIdLocal>>? {
        newReferendum[chainId] ?? referendumUpdate[chainId]
    }
}
