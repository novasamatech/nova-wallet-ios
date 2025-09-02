import Foundation
import Foundation_iOS

final class GovernanceAddDelegationTracksPresenter: GovernanceSelectTracksPresenter {
    var view: GovernanceBaseEditDelegationViewProtocol? {
        get {
            baseView as? GovernanceBaseEditDelegationViewProtocol
        }

        set {
            baseView = newValue
        }
    }

    var wireframe: GovAddDelegationTracksWireframeProtocol? {
        baseWireframe as? GovAddDelegationTracksWireframeProtocol
    }

    var interactor: GovAddDelegationTracksInteractorInputProtocol? {
        baseInteractor as? GovAddDelegationTracksInteractorInputProtocol
    }

    private var isRemoveVotesHintAllowed: Bool = false

    init(
        interactor: GovAddDelegationTracksInteractorInputProtocol,
        wireframe: GovAddDelegationTracksWireframeProtocol,
        chain: ChainModel,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
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

    private func showRemoveVotesHintIfNeeded() {
        if
            isRemoveVotesHintAllowed,
            let votedTracks = votingResult?.value?.votes.votedTracks.keys,
            !votedTracks.isEmpty {
            isRemoveVotesHintAllowed = false

            wireframe?.showRemoveVotesRequest(
                from: view,
                tracksCount: votedTracks.count,
                skipClosure: { [weak self] in
                    self?.interactor?.saveRemoveVotesSkipped()
                }, removeVotesClosure: { [weak self] in
                    self?.showRemoveVotes()
                }
            )
        }
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
        guard tracks != nil, votingResult != nil else {
            return
        }

        selectedTrackIds = Set()
    }

    override func updateView() {
        super.updateView()

        updateTracksAvailabilityView()
        showRemoveVotesHintIfNeeded()
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
            delegate: self,
            votedTracks: votedTracks,
            delegatedTracks: delegatedTracks
        )
    }
}

extension GovernanceAddDelegationTracksPresenter: GovernanceUnavailableTracksDelegate {
    func unavailableTracksDidDecideRemoveVotes() {
        showRemoveVotes()
    }
}

extension GovernanceAddDelegationTracksPresenter: GovAddDelegationTracksInteractorOutputProtocol {
    func didReceiveRemoveVotesHintAllowed(_ isRemoveVotesHintAllowed: Bool) {
        self.isRemoveVotesHintAllowed = isRemoveVotesHintAllowed
    }
}
