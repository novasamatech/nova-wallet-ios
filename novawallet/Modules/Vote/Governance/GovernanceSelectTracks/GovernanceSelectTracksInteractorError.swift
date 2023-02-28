import Foundation

enum GovernanceSelectTracksInteractorError: Error {
    case tracksFetchFailed(Error)
    case votesSubsctiptionFailed(Error)
}
