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
    let willStart: (() -> Void)?
    let didComplete: ((Bool) -> Void)?

    init(
        onError: @escaping () -> Void,
        preservesCondition: @escaping (@escaping (Bool) -> Void) -> Void,
        willStart: (() -> Void)? = nil,
        didComplete: ((Bool) -> Void)? = nil
    ) {
        self.preservesCondition = preservesCondition
        self.onError = onError
        self.willStart = willStart
        self.didComplete = didComplete
    }

    func validate(notifying delegate: DataValidatingDelegate) -> DataValidationProblem? {
        willStart?()

        preservesCondition { [weak self] result in
            self?.didComplete?(result)

            if result {
                delegate.didCompleteAsyncHandling()
            } else {
                self?.onError()
            }
        }

        return .asyncProcess
    }
}
