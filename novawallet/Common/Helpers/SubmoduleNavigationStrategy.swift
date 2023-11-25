import Foundation

enum SubmoduleNavigationStrategy {
    typealias DismissCompletion = () -> Void
    typealias DismissStart = (DismissCompletion?) -> Void
    typealias Callback = () -> Void

    case callbackBeforeDismissal
    case callbackAfterDismissal

    func applyStrategy(for dismissStart: DismissStart, callback: @escaping Callback) {
        switch self {
        case .callbackBeforeDismissal:
            callback()
            dismissStart(nil)
        case .callbackAfterDismissal:
            dismissStart {
                callback()
            }
        }
    }
}
