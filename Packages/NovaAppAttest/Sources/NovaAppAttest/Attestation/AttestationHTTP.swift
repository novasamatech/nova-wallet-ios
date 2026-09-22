import Foundation

public enum AttestationHTTP {
    /// Refuses redirects because they can change the signed request or expose its proof to another host.
    public static let session: URLSession = {
        URLSession(
            configuration: .default,
            delegate: RedirectRefusingDelegate(),
            delegateQueue: nil
        )
    }()

    /// Returns nil for missing or unknown codes; neither establishes an invalid installation.
    public static func errorCode(from data: Data?) -> BackendAttestationErrorCode? {
        rawErrorCode(from: data).flatMap(BackendAttestationErrorCode.init(rawValue:))
    }

    /// Preserves unknown error codes for logging.
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
