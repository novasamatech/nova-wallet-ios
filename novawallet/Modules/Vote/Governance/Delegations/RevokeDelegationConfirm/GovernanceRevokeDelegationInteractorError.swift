import Foundation

enum GovernanceRevokeDelegationInteractorError: Error {
    case submitFailed(_ internalError: Error)
}
