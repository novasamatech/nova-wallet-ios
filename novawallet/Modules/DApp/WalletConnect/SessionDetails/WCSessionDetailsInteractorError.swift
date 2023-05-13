import Foundation

enum WCSessionDetailsInteractorError: Error {
    case sessionUpdateFailed(Error)
    case disconnectionFailed(Error)
}
