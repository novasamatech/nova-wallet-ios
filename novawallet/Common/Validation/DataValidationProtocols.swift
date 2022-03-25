import Foundation

typealias DataValidationRunnerCompletion = () -> Void

enum DataValidationProblem {
    case warning
    case asyncProcess
    case error
}

protocol DataValidatingDelegate: AnyObject {
    func didCompleteWarningHandling()
    func didCompleteAsyncHandling()
}

protocol DataValidating {
    func validate(notifying delegate: DataValidatingDelegate) -> DataValidationProblem?
}

protocol DataValidationRunnerProtocol {
    func runValidation(notifyingOnSuccess closure: @escaping DataValidationRunnerCompletion)
}
