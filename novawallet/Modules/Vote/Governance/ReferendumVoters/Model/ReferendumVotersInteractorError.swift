import Foundation

enum ReferendumVotersInteractorError: Error {
    case votersFetchFailed(_ internalError: Error)
}
