import Foundation

struct GovernanceSelectTrackViewModel {
    struct Track {
        let type: ReferendumTrackType
        let viewModel: SelectableViewModel<ReferendumInfoView.Track>
    }

    enum Group {
        case all(title: String)
        case concrete(trackGroup: ReferendumTrackGroup, title: String)

        var title: String {
            switch self {
            case let .all(title):
                return title
            case let .concrete(_, title):
                return title
            }
        }
    }

    let trackGroups: [Group]
    let availableTracks: [Track]
}
