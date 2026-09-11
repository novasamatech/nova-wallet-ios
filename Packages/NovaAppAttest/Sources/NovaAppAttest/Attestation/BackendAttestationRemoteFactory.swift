import Foundation
import Operation_iOS

public final class BackendAttestationRemoteFactory {
    private let baseURL: URL

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }
}

// MARK: - Status grading

extension BackendAttestationRemoteFactory {
    /// Grades a failed bootstrap call. `code` comes from the gateway's error envelope; it is absent
    /// when a proxy answered instead, and then nothing may be read as a verdict on the installation.
    static func statusError(
        for statusCode: Int,
        code: BackendAttestationErrorCode?,
        isClientAuthenticated: Bool
    ) -> BackendAttestationError? {
        switch statusCode {
        case 200 ..< 300:
            return nil
        case 401, 403, 409:
            // Only a request that carried the identity can be a verdict on it, and only a code that
            // says the binding is finished costs a key: an expired challenge is routine.
            guard isClientAuthenticated, let code else {
                return .clientError(statusCode: statusCode)
            }

            if code.stopsRetrying {
                return .rejected(statusCode: statusCode)
            }

            return code.requiresFreshInstallation
                ? .unauthorized(statusCode: statusCode)
                : .clientError(statusCode: statusCode)
        case 400 ..< 500:
            return .clientError(statusCode: statusCode)
        case 500...:
            return .serverError(statusCode: statusCode)
        default:
            return nil
        }
    }
}

// MARK: - Private

private extension BackendAttestationRemoteFactory {
    enum Constants {
        static let challengesPath = "v1/attestation/challenges"
        static let registerPath = "v1/attestation/register"
    }

    struct ChallengeRequest: Encodable {
        let profile: Int
        let clientId: String
        let purpose: String

        enum CodingKeys: String, CodingKey {
            case profile
            case clientId = "client_id"
            case purpose
        }
    }

    struct ChallengeResponse: Decodable {
        let challenge: String
    }

    struct ErrorEnvelope: Decodable {
        struct Payload: Decodable {
            let code: String
        }

        let error: Payload
    }

    func createPostOperation<T>(
        path: String,
        bodyClosure: @escaping () throws -> Encodable,
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
            request.httpBody = try JSONEncoder().encode(bodyClosure())

            return request
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    /// Unknown codes are preserved as a plain status: the contract adds codes over time and an
    /// unrecognised one must never be upgraded into a verdict.
    static func errorCode(from data: Data?) -> BackendAttestationErrorCode? {
        guard
            let data,
            let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: data)
        else {
            return nil
        }

        return BackendAttestationErrorCode(rawValue: envelope.error.code)
    }

    static func createResultBlock<T>(
        isClientAuthenticated: Bool,
        decoder: @escaping (Data?) throws -> T
    ) -> NetworkResultFactoryBlock<T> {
        { data, response, error in
            if let error {
                return .failure(error)
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(BackendAttestationError.invalidResponse)
            }

            if let statusError = statusError(
                for: httpResponse.statusCode,
                code: errorCode(from: data),
                isClientAuthenticated: isClientAuthenticated
            ) {
                return .failure(statusError)
            }

            return Result { try decoder(data) }
        }
    }
}

// MARK: - BackendAttestationRemoteFactoryProtocol

extension BackendAttestationRemoteFactory: BackendAttestationRemoteFactoryProtocol {
    public func registerTarget() throws -> AttestationRequestTarget {
        try AttestationRequestTarget(
            url: baseURL.appending(path: Constants.registerPath),
            method: HttpMethod.post.rawValue,
            contentType: HttpContentType.json.rawValue
        )
    }

    public func createChallengeWrapper(
        clientId: String,
        purpose: AttestationProfile2.Purpose
    ) -> CompoundOperationWrapper<String> {
        let block: NetworkResultFactoryBlock<String> = Self.createResultBlock(
            isClientAuthenticated: false
        ) { data in
            guard let data else {
                throw BackendAttestationError.invalidResponse
            }

            return try JSONDecoder().decode(ChallengeResponse.self, from: data).challenge
        }

        let operation = createPostOperation(
            path: Constants.challengesPath,
            bodyClosure: {
                ChallengeRequest(
                    profile: AttestationProfile2.version,
                    clientId: clientId,
                    purpose: purpose.wireName
                )
            },
            resultFactory: AnyNetworkResultFactory(block: block)
        )

        return CompoundOperationWrapper(targetOperation: operation)
    }

    public func createRegisterOperation(
        _ requestClosure: @escaping () throws -> BackendAttestationRegisterRequest
    ) -> BaseOperation<Void> {
        let block: NetworkResultFactoryBlock<Void> = Self.createResultBlock(
            isClientAuthenticated: true
        ) { _ in () }

        return createPostOperation(
            path: Constants.registerPath,
            bodyClosure: { try requestClosure() },
            resultFactory: AnyNetworkResultFactory(block: block)
        )
    }
}
