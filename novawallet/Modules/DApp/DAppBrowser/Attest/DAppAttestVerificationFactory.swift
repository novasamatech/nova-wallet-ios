import Foundation
import Operation_iOS

protocol DAppRemoteAttestFactoryProtocol {
    func createGetChallengeWrapper(using baseURL: URL) -> CompoundOperationWrapper<Data>

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

    func createNetworkResulfFactoryBlock<T: Decodable>() -> NetworkResultFactoryBlock<T> {
        { data, response, error in
            if let error {
                return .failure(error)
            }

            if
                let httpUrlResponse = response as? HTTPURLResponse,
                httpUrlResponse.statusCode >= 400 {
                let responseFactory = DAppAttestErrorResponseFactory(code: httpUrlResponse.statusCode)
                return .failure(DAppAttestError.serverError(responseFactory))
            }

            guard let data else {
                return .failure(AppAttestError.invalidResponse)
            }

            do {
                let response = try JSONDecoder().decode(
                    T.self,
                    from: data
                )

                return .success(response)
            } catch {
                return .failure(error)
            }
        }
    }

    func createNetworkResulfFactoryBlock() -> NetworkResultFactoryBlock<Void> {
        { data, response, error in
            if let error {
                return .failure(error)
            }

            if
                let httpUrlResponse = response as? HTTPURLResponse,
                httpUrlResponse.statusCode >= 400 {
                let responseFactory = DAppAttestErrorResponseFactory(code: httpUrlResponse.statusCode)
                return .failure(DAppAttestError.serverError(responseFactory))
            }

            guard data != nil else {
                return .failure(AppAttestError.invalidResponse)
            }

            return .success(())
        }
    }
}

// MARK: - DAppAttestVerificationFactoryProtocol

extension DAppRemoteAttestFactory: DAppRemoteAttestFactoryProtocol {
    func createGetChallengeWrapper(using baseURL: URL) -> CompoundOperationWrapper<Data> {
        let fullURL = baseURL.appending(path: Constants.challengesEndpoint)

        let block: NetworkResultFactoryBlock<AppAttestChallengeResponse> = createNetworkResulfFactoryBlock()

        let responseFactory = AnyNetworkResultFactory(block: block)

        let requestOperation = createGenericRequestOperation(
            for: fullURL,
            bodyParamsClosure: { nil },
            method: HttpMethod.post.rawValue,
            responseFactory: responseFactory
        )

        let mapOperation = ClosureOperation<Data> {
            let result = try requestOperation.extractNoCancellableResultData()

            return result.challenge
        }

        mapOperation.addDependency(requestOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [requestOperation]
        )
    }

    func createAttestationOperation(
        using baseURL: URL,
        _ dataClosure: @escaping () throws -> DAppAttestRequest
    ) -> BaseOperation<Void> {
        let fullURL = baseURL.appending(path: Constants.attestationsEndpoint)

        let block = createNetworkResulfFactoryBlock()

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
