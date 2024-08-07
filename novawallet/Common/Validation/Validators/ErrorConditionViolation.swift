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

final class AsyncValidationOnProgress {
    let willStart: (() -> Void)?
    let didComplete: ((Bool) -> Void)?

    init(willStart: (() -> Void)?, didComplete: ((Bool) -> Void)?) {
        self.willStart = willStart
        self.didComplete = didComplete
    }
}

final class AsyncErrorConditionViolation: DataValidating {
    let preservesCondition: (@escaping (Bool) -> Void) -> Void
    let onError: () -> Void
    let onProgress: AsyncValidationOnProgress?

    init(
        onError: @escaping () -> Void,
        preservesCondition: @escaping (@escaping (Bool) -> Void) -> Void,
        onProgress: AsyncValidationOnProgress? = nil
    ) {
        self.preservesCondition = preservesCondition
        self.onError = onError
        self.onProgress = onProgress
    }

    func validate(notifying delegate: DataValidatingDelegate) -> DataValidationProblem? {
        onProgress?.willStart?()

        preservesCondition { [weak self] result in
            DispatchQueue.main.async {
                self?.onProgress?.didComplete?(result)

                if result {
                    delegate.didCompleteAsyncHandling()
                } else {
                    self?.onError()
                }
            }
        }

        return .asyncProcess
    }
}
