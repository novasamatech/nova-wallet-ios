struct GovernanceNotificationsModel {
    var identifier: ChainModel.Id
    var enabled: Bool
    var icon: ImageViewModelProtocol?
    var name: String
    var newReferendum: Bool
    var referendumUpdate: Bool
    var delegateHasVoted: Bool
    var tracks: SelectedTracks

    enum SelectedTracks {
        case all
        case concrete(Set<TrackIdLocal>, count: Int)
    }

    var allNotificationsIsOff: Bool {
        newReferendum == false &&
            referendumUpdate == false &&
            delegateHasVoted == false
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

    mutating func set(selectedTracks: Set<TrackIdLocal>, count: Int) {
        if selectedTracks.count == count {
            tracks = .all
        } else {
            tracks = .concrete(selectedTracks, count: count)
        }
    }
}
