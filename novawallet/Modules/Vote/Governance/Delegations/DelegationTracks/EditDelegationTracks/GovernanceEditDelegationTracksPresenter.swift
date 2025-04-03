import Foundation
import Foundation_iOS

final class GovEditDelegationTracksPresenter: GovernanceSelectTracksPresenter {
    var view: GovernanceBaseEditDelegationViewProtocol? {
        get {
            baseView as? GovernanceBaseEditDelegationViewProtocol
        }

        set {
            baseView = newValue
        }
    }

    var wireframe: GovEditDelegationTracksWireframeProtocol? {
        baseWireframe as? GovEditDelegationTracksWireframeProtocol
    }

    let delegateId: AccountId

    init(
        interactor: GovernanceSelectTracksInteractorInputProtocol,
        wireframe: GovEditDelegationTracksWireframeProtocol,
        delegateId: AccountId,
        chain: ChainModel,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.delegateId = delegateId

        super.init(
            baseInteractor: interactor,
            baseWireframe: wireframe,
            chain: chain,
            localizationManager: localizationManager,
            logger: logger
        )
    }

    private func showRemoveVotes() {
        guard let voting = votingResult?.value, let tracks = tracks else {
            return
        }

        let votedTrackIds = Set(voting.votes.votedTracks.keys)
        let votedTracks = tracks.filter { votedTrackIds.contains($0.trackId) }

        wireframe?.showRemoveVotes(
            from: view,
            tracks: votedTracks
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
        let delegatedTracks = Set(voting.votes.delegatings.filter { $0.value.target != delegateId }.keys)

        return votedTracks.union(delegatedTracks)
    }

    override func setupAvailableTracks() {
        guard
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
        guard let tracks = tracks, let delegatings = votingResult?.value?.votes.delegatings else {
            return
        }

        let selectedTracksList = tracks.filter { track in
            if let delegating = delegatings[track.trackId] {
                return delegating.target == delegateId
            } else {
                return false
            }
        }

        selectedTrackIds = Set(selectedTracksList.map(\.trackId))
    }

    override func updateView() {
        super.updateView()

        updateTracksAvailabilityView()
    }
}

extension GovEditDelegationTracksPresenter: GovernanceBaseEditDelegationPresenterProtocol {
    func showUnavailableTracks() {
        guard
            let voting = votingResult?.value,
            let tracks = tracks else {
            return
        }

        let votedTrackIds = Set(voting.votes.votedTracks.keys)
        let delegatedTrackIds = Set(voting.votes.delegatings.filter { $0.value.target != delegateId }.keys)

        let votedTracks = tracks.filter { votedTrackIds.contains($0.trackId) }
        let delegatedTracks = tracks.filter { delegatedTrackIds.contains($0.trackId) }

        wireframe?.presentUnavailableTracks(
            from: view,
            delegate: self,
            votedTracks: votedTracks,
            delegatedTracks: delegatedTracks
        )
    }
}

extension GovEditDelegationTracksPresenter: GovernanceUnavailableTracksDelegate {
    func unavailableTracksDidDecideRemoveVotes() {
        showRemoveVotes()
    }
}
