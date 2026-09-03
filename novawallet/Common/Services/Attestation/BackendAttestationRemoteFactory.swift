import Foundation
import Operation_iOS

/// The two gateway attestation endpoints of spec §7.6. The result factory is a raw
/// `AnyNetworkResultFactory(block:)` because `successResponseBlock:` collapses 403 into
/// `unexpectedStatusCode` and `processingBlock:` fails an empty 2xx body.
final class BackendAttestationRemoteFactory {
    private let baseURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
    }
}

// MARK: - Private

private extension BackendAttestationRemoteFactory {
    enum Constants {
        static let challengesPath = "v1/attestation/challenges"
        static let registerPath = "v1/attestation/register"
    }

    struct ChallengeResponse: Decodable {
        let challenge: String
    }

    static func statusError(for statusCode: Int) -> BackendAttestationError? {
        switch statusCode {
        case 401, 403:
            return .rejected(statusCode: statusCode)
        case 400 ..< 500:
            return .clientError(statusCode: statusCode)
        case 500...:
            return .serverError(statusCode: statusCode)
        default:
            return nil
        }
    }

    func createPostOperation<T>(
        path: String,
        bodyClosure: @escaping () throws -> Encodable?,
        resultFactory: AnyNetworkResultFactory<T>
    ) -> NetworkOperation<T> {
        let url = baseURL.appending(path: path)

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.post.rawValue
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )

            if let body = try bodyClosure() {
                request.httpBody = try JSONEncoder().encode(body)
            }

            return request
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    /// Maps transport and status onto `BackendAttestationError`, then hands the body to
    /// `decoder`. A nil `decoder` means the endpoint returns no body of interest.
    static func createResultBlock<T>(
        decoder: @escaping (Data?) throws -> T
    ) -> NetworkResultFactoryBlock<T> {
        { data, response, error in
            if let error {
                return .failure(error)
            }

            if
                let httpResponse = response as? HTTPURLResponse,
                let statusError = statusError(for: httpResponse.statusCode) {
                return .failure(statusError)
            }

            return Result { try decoder(data) }
        }
    }
}

// MARK: - BackendAttestationRemoteFactoryProtocol

extension BackendAttestationRemoteFactory: BackendAttestationRemoteFactoryProtocol {
    func createChallengeWrapper() -> CompoundOperationWrapper<String> {
        let block: NetworkResultFactoryBlock<String> = Self.createResultBlock { data in
            guard let data else {
                throw AppAttestError.invalidResponse
            }

            // The challenge is opaque and is never hex-decoded (spec §7.6).
            return try JSONDecoder().decode(ChallengeResponse.self, from: data).challenge
        }

        let operation = createPostOperation(
            path: Constants.challengesPath,
            bodyClosure: { nil },
            resultFactory: AnyNetworkResultFactory(block: block)
        )

        return CompoundOperationWrapper(targetOperation: operation)
    }

    func createRegisterOperation(
        _ requestClosure: @escaping () throws -> BackendAttestationRegisterRequest
    ) -> BaseOperation<Void> {
        let block: NetworkResultFactoryBlock<Void> = Self.createResultBlock { _ in () }

        return createPostOperation(
            path: Constants.registerPath,
            bodyClosure: { try requestClosure() },
            resultFactory: AnyNetworkResultFactory(block: block)
        )
    }
}
