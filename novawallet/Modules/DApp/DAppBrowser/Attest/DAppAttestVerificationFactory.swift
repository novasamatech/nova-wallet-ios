import Foundation
import Operation_iOS

protocol DAppRemoteAttestFactoryProtocol {
    func createGetChallengeOperation(using baseURL: URL) -> BaseOperation<Data>

    func createAttestationOperation(
        using baseURL: URL,
        _ dataClosure: @escaping () throws -> DAppAttestRequest
    ) -> BaseOperation<Void>
}

final class DAppRemoteAttestFactory {
    private func createGenericRequestOperation<R>(
        for url: URL,
        bodyParamsClosure: @escaping () throws -> Encodable?,
        method: String,
        responseFactory: AnyNetworkResultFactory<R>
    ) -> NetworkOperation<R> {
        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.httpMethod = method
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )

            let bodyParams = try bodyParamsClosure()

            if let bodyParams {
                request.httpBody = try JSONEncoder().encode(bodyParams)
            }

            return request
        }

        return NetworkOperation(
            requestFactory: requestFactory,
            resultFactory: AnyNetworkResultFactory(factory: responseFactory)
        )
    }
}

// MARK: - DAppAttestVerificationFactoryProtocol

extension DAppRemoteAttestFactory: DAppRemoteAttestFactoryProtocol {
    func createGetChallengeOperation(using baseURL: URL) -> BaseOperation<Data> {
        let fullURL = baseURL.appending(path: Constants.challengesEndpoint)

        let responseFactory = AnyNetworkResultFactory<Data> { data in
            let response = try JSONDecoder().decode(
                AppAttestChallengeResponse.self,
                from: data
            )

            return response.challenge.data(using: .utf8) ?? Data(response.challenge.bytes)
        }

        return createGenericRequestOperation(
            for: fullURL,
            bodyParamsClosure: { nil },
            method: HttpMethod.post.rawValue,
            responseFactory: responseFactory
        )
    }

    func createAttestationOperation(
        using baseURL: URL,
        _ dataClosure: @escaping () throws -> DAppAttestRequest
    ) -> BaseOperation<Void> {
        let fullURL = baseURL.appending(path: Constants.attestationsEndpoint)

        return createGenericRequestOperation(
            for: fullURL,
            bodyParamsClosure: { try dataClosure() },
            method: HttpMethod.post.rawValue,
            responseFactory: AnyNetworkResultFactory<Void> {}
        )
    }
}

// MARK: - Constants

private extension DAppRemoteAttestFactory {
    enum Constants {
        static let challengesEndpoint = "challenges"
        static let attestationsEndpoint = "app-attest/attestations"
    }
}
