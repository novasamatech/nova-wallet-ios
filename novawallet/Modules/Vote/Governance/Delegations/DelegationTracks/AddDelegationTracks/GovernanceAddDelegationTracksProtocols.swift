import Foundation

protocol GovAddDelegationTracksWireframeProtocol: GovernanceBaseEditDelegationWireframeProtocol {
    func showRemoveVotesRequest(
        from view: ControllerBackedProtocol?,
        tracksCount: Int,
        skipClosure: @escaping () -> Void,
        removeVotesClosure: @escaping () -> Void
    )

    func showRemoveVotes(
        from view: ControllerBackedProtocol?,
        tracks: [GovernanceTrackInfoLocal]
    )
}

protocol GovAddDelegationTracksInteractorInputProtocol: GovernanceSelectTracksInteractorInputProtocol {
    func saveRemoveVotesSkipped()
}

protocol GovAddDelegationTracksInteractorOutputProtocol: GovernanceSelectTracksInteractorOutputProtocol {
    func didReceiveRemoveVotesHintAllowed(_ isRemoveVotesHintAllowed: Bool)
}
