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
    static func statusError(
        for statusCode: Int,
        expecting successStatus: Int,
        code: BackendAttestationErrorCode?,
        isClientAuthenticated: Bool
    ) -> BackendAttestationError? {
        switch statusCode {
        case successStatus:
            return nil
        case 200 ..< 400:
            // Only the expected status confirms success; intermediaries may return other statuses.
            return .invalidResponse
        case 401, 403, 409:
            // Retire an identity only when its authenticated request receives a binding error code.
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
        default:
            return .serverError(statusCode: statusCode)
        }
    }
}

// MARK: - Private

private extension BackendAttestationRemoteFactory {
    enum Constants {
        static let challengesPath = "v1/attestation/challenges"
        static let registerPath = "v1/attestation/register"
        static let challengeSuccessStatus = 200
        static let registerSuccessStatus = 204
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

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
        operation.networkSession = AttestationHTTP.session

        return operation
    }

    static func createResultBlock<T>(
        expecting successStatus: Int,
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
                expecting: successStatus,
                code: AttestationHTTP.errorCode(from: data),
                isClientAuthenticated: isClientAuthenticated
            ) {
                return .failure(statusError)
            }

            return Result { try decoder(data) }
        }
    }
}

// MARK: - Remote factory protocol

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
        // Only request challenges authenticate a registered client and can invalidate its binding.
        let block: NetworkResultFactoryBlock<String> = Self.createResultBlock(
            expecting: Constants.challengeSuccessStatus,
            isClientAuthenticated: purpose == .request
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
            expecting: Constants.registerSuccessStatus,
            isClientAuthenticated: true
        ) { _ in () }

        return createPostOperation(
            path: Constants.registerPath,
            bodyClosure: { try requestClosure() },
            resultFactory: AnyNetworkResultFactory(block: block)
        )
    }
}
