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
            resultFactory: responseFactory
        )
    }
}

// MARK: - DAppAttestVerificationFactoryProtocol

extension DAppRemoteAttestFactory: DAppRemoteAttestFactoryProtocol {
    func createGetChallengeOperation(using baseURL: URL) -> BaseOperation<Data> {
        let fullURL = baseURL.appending(path: Constants.challengesEndpoint)

        let block: NetworkResultFactoryBlock<Data> = { data, _, error in
            if let error {
                return .failure(error)
            } else if let data {
                do {
                    let response = try JSONDecoder().decode(
                        AppAttestChallengeResponse.self,
                        from: data
                    )

                    return .success(response.challenge)
                } catch {
                    return .failure(error)
                }
            } else {
                return .failure(AppAttestError.invalidResponse)
            }
        }

        let responseFactory = AnyNetworkResultFactory(block: block)

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

        let block: NetworkResultFactoryBlock<Void> = { data, _, error in
            if let error {
                .failure(error)
            } else if let data {
                .success(())
            } else {
                .failure(AppAttestError.invalidResponse)
            }
        }

        return createGenericRequestOperation(
            for: fullURL,
            bodyParamsClosure: { try dataClosure() },
            method: HttpMethod.post.rawValue,
            responseFactory: AnyNetworkResultFactory(block: block)
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
