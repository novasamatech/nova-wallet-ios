import Foundation
import Operation_iOS

public final class BackendAttestationRemoteFactory {
    private let baseURL: URL

    public init(baseURL: URL) {
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

    static func statusError(
        for statusCode: Int,
        isClientAuthenticated: Bool
    ) -> BackendAttestationError? {
        switch statusCode {
        case 401, 403:
            return isClientAuthenticated
                ? .rejected(statusCode: statusCode)
                : .clientError(statusCode: statusCode)
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

    static func createResultBlock<T>(
        isClientAuthenticated: Bool,
        decoder: @escaping (Data?) throws -> T
    ) -> NetworkResultFactoryBlock<T> {
        { data, response, error in
            if let error {
                return .failure(error)
            }

            if
                let httpResponse = response as? HTTPURLResponse,
                let statusError = statusError(
                    for: httpResponse.statusCode,
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
    public func createChallengeWrapper() -> CompoundOperationWrapper<String> {
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
            bodyClosure: { nil },
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
