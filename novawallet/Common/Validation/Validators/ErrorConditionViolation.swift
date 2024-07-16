import Foundation

final class ErrorConditionViolation: DataValidating {
    let preservesCondition: () -> Bool
    let onError: () -> Void

    init(
        onError: @escaping () -> Void,
        preservesCondition: @escaping () -> Bool
    ) {
        self.preservesCondition = preservesCondition
        self.onError = onError
    }

    func validate(notifying _: DataValidatingDelegate) -> DataValidationProblem? {
        if preservesCondition() {
            return nil
        }

        onError()

        return .error
    }
}

final class AsyncErrorConditionViolation: DataValidating {
    let preservesCondition: (@escaping (Bool) -> Void) -> Void
    let onError: () -> Void

    init(
        onError: @escaping () -> Void,
        preservesCondition: @escaping (@escaping (Bool) -> Void) -> Void
    ) {
        self.preservesCondition = preservesCondition
        self.onError = onError
    }

    func validate(notifying delegate: DataValidatingDelegate) -> DataValidationProblem? {
        preservesCondition { [weak self] result in
            if result {
                delegate.didCompleteAsyncHandling()
            } else {
                self?.onError()
            }
        }

        return .asyncProcess
    }
}
