import Foundation
import SoraFoundation

final class GovernanceTracksSettingsPresenter: SelectTracksPresenter {
    weak var view: GovernanceTracksSettingsViewProtocol? {
        get {
            selectTracksView as? GovernanceTracksSettingsViewProtocol
        }
        set {
            selectTracksView = newValue
        }
    }

    var wireframe: GovernanceTracksSettingsWireframeProtocol? {
        selectTracksWireframe as? GovernanceTracksSettingsWireframeProtocol
    }

    private let initialSelectedTracks: Set<TrackIdLocal>?

    init(
        initialSelectedTracks: Set<TrackIdLocal>?,
        interactor: SelectTracksInteractorInputProtocol,
        wireframe: GovernanceTracksSettingsWireframeProtocol,
        localizationManager: LocalizationManagerProtocol,
        chain: ChainModel,
        logger: LoggerProtocol
    ) {
        self.initialSelectedTracks = initialSelectedTracks
        super.init(
            interactor: interactor,
            wireframe: wireframe,
            chain: chain,
            localizationManager: localizationManager,
            logger: logger
        )
    }

    override func setupAvailableTracks() {
        guard let tracks = tracks else {
            return
        }
        availableTrackIds = Set(tracks.map(\.trackId))
    }

    override func setupSelectedTracks() {
        guard var tracks = tracks else {
            return
        }
        if let initialSelectedTracks = initialSelectedTracks {
            tracks = tracks.filter {
                initialSelectedTracks.contains($0.trackId)
            }
        }
        selectedTracks = Set(tracks.compactMap { ReferendumTrackType(rawValue: $0.name) })
    }

    override func setup() {
        super.setup()
        view?.didReceive(networkViewModel: .init(
            name: chain.name,
            icon: RemoteImageViewModel(url: chain.icon)
        ))
    }

    override func toggleTrackSelection(track: GovernanceSelectTrackViewModel.Track) {
        guard let selectedTracks = selectedTracks else {
            return
        }

        if selectedTracks.contains(track.type), selectedTracks.count == 1 {
            return
        }

        super.toggleTrackSelection(track: track)
    }

    override func proceed() {
        guard let selectedTrackTypes = selectedTracks, let allTracks = tracks else {
            return
        }

        let selectedTracks = allTracks.filter { track in
            guard let trackType = ReferendumTrackType(rawValue: track.name) else {
                return false
            }

            return selectedTrackTypes.contains(trackType)
        }

        let tracksCount = allTracks.compactMap { ReferendumTrackType(rawValue: $0.name) }.count

        wireframe?.proceed(from: view, tracks: selectedTracks, totalCount: tracksCount)
    }
}
