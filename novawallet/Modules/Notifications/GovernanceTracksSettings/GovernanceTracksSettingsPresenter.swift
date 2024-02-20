import Foundation
import SoraFoundation

final class GovernanceTracksSettingsPresenter: GovernanceSelectTracksPresenter {
    weak var view: GovernanceTracksSettingsViewProtocol? {
        baseView as? GovernanceTracksSettingsViewProtocol
    }

    var wireframe: GovernanceTracksSettingsWireframeProtocol? {
        baseWireframe as? GovernanceTracksSettingsWireframeProtocol
    }

    var interactor: GovernanceTracksSettingsInteractorInputProtocol? {
        baseInteractor as? GovernanceTracksSettingsInteractorInputProtocol
    }

    private let initialSelectedTracks: Set<TrackIdLocal>?

    init(
        initialSelectedTracks: Set<TrackIdLocal>?,
        interactor: GovernanceTracksSettingsInteractorInputProtocol,
        wireframe: GovernanceTracksSettingsWireframeProtocol,
        localizationManager: LocalizationManagerProtocol,
        chain: ChainModel,
        logger: LoggerProtocol
    ) {
        self.initialSelectedTracks = initialSelectedTracks
        super.init(
            baseInteractor: interactor,
            baseWireframe: wireframe,
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

extension GovernanceTracksSettingsPresenter: GovernanceTracksSettingsPresenterProtocol {}

extension GovernanceTracksSettingsPresenter: GovernanceTracksSettingsInteractorOutputProtocol {}
