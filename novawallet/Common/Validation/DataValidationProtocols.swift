import Foundation

typealias DataValidationRunnerCompletion = () -> Void
typealias DataValidationRunnerStopClosure = (DataValidationProblem) -> Void
typealias DataValidationRunnerResumeClosure = (Int) -> Void

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
    func runValidation(
        notifyingOnSuccess completionClosure: @escaping DataValidationRunnerCompletion,
        notifyingOnStop stopClosure: DataValidationRunnerStopClosure?,
        notifyingOnResume resumeClosure: DataValidationRunnerResumeClosure?
    )
}

extension DataValidationRunnerProtocol {
    func runValidation(notifyingOnSuccess closure: @escaping DataValidationRunnerCompletion) {
        runValidation(
            notifyingOnSuccess: closure,
            notifyingOnStop: nil,
            notifyingOnResume: nil
        )
    }
}
