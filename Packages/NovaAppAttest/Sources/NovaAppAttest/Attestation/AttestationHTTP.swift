import Foundation

/// Transport rules a proof-consuming request cannot be correct without.
public enum AttestationHTTP {
    /// A proof names one destination and one body. A redirect would carry both to somewhere the
    /// gateway never signed — a 303 arrives as a GET and is refused as an invalid target, a 308
    /// carries the proof headers verbatim to another host — so redirects are refused outright and
    /// surface as an ordinary transport failure.
    public static let session: URLSession = {
        URLSession(
            configuration: .default,
            delegate: RedirectRefusingDelegate(),
            delegateQueue: nil
        )
    }()

    /// The gateway's error code, or nil when a proxy answered instead of the gateway. The code space
    /// is deliberately open, so an unrecognised code stays nil and is never read as a verdict.
    public static func errorCode(from data: Data?) -> BackendAttestationErrorCode? {
        rawErrorCode(from: data).flatMap(BackendAttestationErrorCode.init(rawValue:))
    }

    /// Kept separate from `errorCode(from:)` so an unrecognised code can still be logged.
    public static func rawErrorCode(from data: Data?) -> String? {
        guard let data else {
            return nil
        }

        return try? JSONDecoder().decode(ErrorEnvelope.self, from: data).error.code
    }
}

// MARK: - Private

private extension AttestationHTTP {
    struct ErrorEnvelope: Decodable {
        struct Payload: Decodable {
            let code: String
        }

        let error: Payload
    }
}

private final class RedirectRefusingDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        willPerformHTTPRedirection _: HTTPURLResponse,
        newRequest _: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
