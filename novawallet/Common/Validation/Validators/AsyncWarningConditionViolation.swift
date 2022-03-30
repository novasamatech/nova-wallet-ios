import Foundation

final class AsyncWarningConditionViolation: DataValidating {
    let preservesCondition: (@escaping (Bool) -> Void) -> Void
    let onWarning: (DataValidatingDelegate) -> Void

    init(
        onWarning: @escaping (DataValidatingDelegate) -> Void,
        preservesCondition: @escaping (@escaping (Bool) -> Void) -> Void
    ) {
        self.preservesCondition = preservesCondition
        self.onWarning = onWarning
    }

    func validate(notifying delegate: DataValidatingDelegate) -> DataValidationProblem? {
        preservesCondition { [weak self] result in
            if result {
                delegate.didCompleteAsyncHandling()
            } else {
                self?.onWarning(delegate)
            }
        }

        return .asyncProcess
    }
}
