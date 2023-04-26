import Foundation

enum DAppInteractionError: Error {
    case phishingVerifierFailed(Error)
}
