import Foundation
import Foundation_iOS

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
        selectedTrackIds = Set(tracks.map(\.trackId))
    }

    override func setup() {
        super.setup()
        view?.didReceive(networkViewModel: .init(
            name: chain.name,
            icon: ImageViewModelFactory.createChainIconOrDefault(from: chain.icon)
        ))
    }

    override func toggleTrackSelection(track: GovernanceSelectTrackViewModel.Track) {
        guard let selectedTrackIds else {
            return
        }

        if selectedTrackIds.contains(track.trackId), selectedTrackIds.count == 1 {
            return
        }

        super.toggleTrackSelection(track: track)
    }

    override func proceed() {
        guard let selectedTrackIds, let allTracks = tracks else {
            return
        }

        let selectedTracks = allTracks.filter { track in
            selectedTrackIds.contains(track.trackId)
        }

        wireframe?.proceed(from: view, tracks: selectedTracks, totalCount: allTracks.count)
    }
}
