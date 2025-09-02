import Foundation

protocol ExtrinsicStatusValidating {
    func ensureSuccess(from events: [Event], codingFactory: RuntimeCoderFactoryProtocol) throws
}

enum ExtrinsicStatusValidatorError: Error {
    case terminateEventNotFound([Event])
    case errorDecodingFailed
}

final class ExtrinsicStatusValidator {
    let logger: LoggerProtocol

    init(logger: LoggerProtocol) {
        self.logger = logger
    }
}

extension ExtrinsicStatusValidator: ExtrinsicStatusValidating {
    func ensureSuccess(from events: [Event], codingFactory: RuntimeCoderFactoryProtocol) throws {
        let successMatcher = ExtrinsicSuccessEventMatcher()

        guard !successMatcher.matchList(events, using: codingFactory) else {
            return
        }

        let failMatcher = ExtrinsicFailureEventMatcher()

        guard let failureEvent = failMatcher.firstMatchingFromList(events, using: codingFactory) else {
            throw ExtrinsicStatusValidatorError.terminateEventNotFound(events)
        }

        let errorDecoder = CallDispatchErrorDecoder(logger: logger)

        guard
            let dispatchError = errorDecoder.decode(
                errorParams: failureEvent.params,
                using: codingFactory
            ) else {
            throw ExtrinsicStatusValidatorError.errorDecodingFailed
        }

        throw dispatchError
    }
}
