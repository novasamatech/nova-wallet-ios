import Foundation

/// Why an answer of the mirror was not used
enum ConfigMirrorFailure: Error {
    /// The request ended with an error of the url loading system
    case transport(Error)
    case deadlineExceeded
    /// A redirect comes here too: it is not followed, so its status is the answer
    case unexpectedStatus(Int?)
    case emptyBody
    case malformedJson
    case missingCommitHeader
}

/// What a finished mirror attempt tells about the mirror as a whole
enum ConfigMirrorAttemptVerdict: Equatable {
    /// The mirror answered over the network and the answer doesn't call for a pause
    case reachable
    /// The mirror is to be left alone for a while
    case unavailable
    /// Nothing was learned: the attempt was cancelled, never left the device or was answered by the http cache
    case unknown
}

extension ConfigMirrorFailure {
    var verdict: ConfigMirrorAttemptVerdict {
        switch self {
        case let .transport(error):
            return Self.verdict(ofTransportError: error)
        case .deadlineExceeded:
            return .unavailable
        case let .unexpectedStatus(statusCode?):
            return Self.isUnavailabilityStatus(statusCode) ? .unavailable : .reachable
        case .unexpectedStatus(nil):
            return .unknown
        case .emptyBody, .malformedJson, .missingCommitHeader:
            // a missing file or an unusable body concerns one file and is answered fast
            return .reachable
        }
    }
}

// MARK: Private

private extension ConfigMirrorFailure {
    enum Constants {
        static let serverErrorStatusCode = 500
        static let tooManyRequestsStatusCode = 429

        // A cancellation and the errors of the device's own connectivity say nothing about the mirror
        static let unrelatedErrorCodes: Set<URLError.Code> = [
            .cancelled,
            .notConnectedToInternet,
            .dataNotAllowed,
            .internationalRoamingOff,
            .callIsActive
        ]
    }

    static func isUnavailabilityStatus(_ statusCode: Int) -> Bool {
        statusCode >= Constants.serverErrorStatusCode || statusCode == Constants.tooManyRequestsStatusCode
    }

    static func verdict(ofTransportError error: Error) -> ConfigMirrorAttemptVerdict {
        guard let urlError = error as? URLError else {
            return .unknown
        }

        return Constants.unrelatedErrorCodes.contains(urlError.code) ? .unknown : .unavailable
    }
}
