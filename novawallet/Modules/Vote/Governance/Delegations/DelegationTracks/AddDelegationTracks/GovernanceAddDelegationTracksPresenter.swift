import Foundation
import SoraFoundation

final class GovernanceAddDelegationTracksPresenter: GovernanceSelectTracksPresenter {
    var view: GovernanceBaseEditDelegationViewProtocol? {
        get {
            baseView as? GovernanceBaseEditDelegationViewProtocol
        }

        set {
            baseView = newValue
        }
    }

    var wireframe: GovernanceBaseEditDelegationWireframeProtocol? {
        baseWireframe as? GovernanceBaseEditDelegationWireframeProtocol
    }

    init(
        interactor: GovernanceSelectTracksInteractorInputProtocol,
        wireframe: GovernanceBaseEditDelegationWireframeProtocol,
        chain: ChainModel,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        super.init(
            interactor: interactor,
            baseWireframe: wireframe,
            chain: chain,
            localizationManager: localizationManager,
            logger: logger
        )
    }

    private func updateTracksAvailabilityView() {
        guard let tracks = tracks, let availableTrackIds = availableTrackIds else {
            return
        }

        let hasUnavailableTracks = tracks.count != availableTrackIds.count

        view?.didReceive(hasUnavailableTracks: hasUnavailableTracks)
    }

    private func getUnavailableTrackIds() -> Set<TrackIdLocal>? {
        guard let voting = votingResult?.value else {
            return nil
        }

        let votedTracks = Set(voting.votes.votedTracks.keys)
        let delegatedTracks = Set(voting.votes.delegatings.keys)

        return votedTracks.union(delegatedTracks)
    }

    override func setupAvailableTracks() {
        guard
            availableTrackIds == nil,
            let unavailableTrackIds = getUnavailableTrackIds(),
            let tracks = tracks else {
            return
        }

        let availableTrackIdList = tracks.compactMap {
            if !unavailableTrackIds.contains($0.trackId) {
                return $0.trackId
            } else {
                return nil
            }
        }

        availableTrackIds = Set(availableTrackIdList)
    }

    override func setupSelectedTracks() {
        guard selectedTracks == nil, tracks != nil, votingResult != nil else {
            return
        }

        selectedTracks = Set()
    }

    override func updateView() {
        super.updateView()

        updateTracksAvailabilityView()
    }
}

extension GovernanceAddDelegationTracksPresenter: GovernanceBaseEditDelegationPresenterProtocol {
    func showUnavailableTracks() {
        guard
            let voting = votingResult?.value,
            let tracks = tracks else {
            return
        }

        let votedTrackIds = Set(voting.votes.votedTracks.keys)
        let delegatedTrackIds = Set(voting.votes.delegatings.keys)

        let votedTracks = tracks.filter { votedTrackIds.contains($0.trackId) }
        let delegatedTracks = tracks.filter { delegatedTrackIds.contains($0.trackId) }

        wireframe?.presentUnavailableTracks(
            from: view,
            votedTracks: votedTracks,
            delegatedTracks: delegatedTracks
        )
    }
}
