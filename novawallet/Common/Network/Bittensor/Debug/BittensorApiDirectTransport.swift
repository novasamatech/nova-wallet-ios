import Foundation
import Operation_iOS

#if DEBUG
    // Debug-only path for a Bittensor service reached without the attested edge, such as a
    // local service during development: `-BittensorApiBaseURL http://127.0.0.1:8002`.
    enum BittensorApiDirectMode {
        static let launchArgument = "-BittensorApiBaseURL"

        static var baseURL: URL? {
            let arguments = ProcessInfo.processInfo.arguments

            guard
                let index = arguments.firstIndex(of: launchArgument),
                arguments.indices.contains(index + 1) else {
                return nil
            }

            return URL(string: arguments[index + 1])
        }
    }

    final class BittensorApiDirectTransport {
        private let baseURL: URL
        private let session: URLSession
        private let logger: LoggerProtocol

        init(
            baseURL: URL,
            session: URLSession = URLSession(configuration: .ephemeral),
            logger: LoggerProtocol
        ) {
            self.baseURL = baseURL
            self.session = session
            self.logger = logger
        }
    }

    extension BittensorApiDirectTransport: BittensorApiTransportProtocol {
        func createResponseWrapper(
            for request: BittensorApiRequest
        ) -> CompoundOperationWrapper<BittensorApiRawResponse> {
            let url: URL

            do {
                url = try BittensorAttestedRequestBuilder.createURL(for: request, baseURL: baseURL)
            } catch {
                return .createWithError(error)
            }

            let route = "Bittensor \(request.method.rawValue) \(request.pathTemplate)"
            let sendOperation = createSendOperation(for: request, url: url)

            let gradeOperation = ClosureOperation<BittensorApiRawResponse> { [logger] in
                let response: BittensorAttestedResponse

                do {
                    response = try sendOperation.extractNoCancellableResultData()
                } catch {
                    logger.warning("\(route) direct transport failure: \(error)")

                    throw BittensorApiError.transport(error)
                }

                switch BittensorAttestedResponseGrader.grade(response) {
                case let .success(rawResponse):
                    logger.debug("\(route) -> \(response.statusCode) request id \(response.requestId ?? "-")")

                    return rawResponse
                case let .failure(error):
                    logger.warning("\(route) -> \(response.statusCode) \(error)")

                    throw error
                case .retryWithFreshProof, .unknownClient:
                    throw BittensorApiError.attestationFailure(requestId: response.requestId)
                }
            }

            gradeOperation.addDependency(sendOperation)

            return CompoundOperationWrapper(targetOperation: gradeOperation, dependencies: [sendOperation])
        }
    }

    private extension BittensorApiDirectTransport {
        enum Constants {
            static let requestIdHeader = "X-Request-ID"
        }

        func createSendOperation(
            for request: BittensorApiRequest,
            url: URL
        ) -> NetworkOperation<BittensorAttestedResponse> {
            let requestFactory = BlockNetworkRequestFactory {
                var urlRequest = URLRequest(
                    url: url,
                    cachePolicy: .reloadIgnoringLocalCacheData,
                    timeoutInterval: BittensorAttestedRequestBuilder.requestTimeout
                )

                urlRequest.httpMethod = request.method.rawValue

                if let body = request.jsonBody {
                    urlRequest.httpBody = body
                    urlRequest.setValue(
                        HttpContentType.json.rawValue,
                        forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
                    )
                }

                return urlRequest
            }

            let resultFactory = AnyNetworkResultFactory<BittensorAttestedResponse> { data, response, error in
                if let error {
                    return .failure(error)
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    return .failure(URLError(.badServerResponse))
                }

                return .success(
                    BittensorAttestedResponse(
                        statusCode: httpResponse.statusCode,
                        contentType: httpResponse.value(forHTTPHeaderField: HttpHeaderKey.contentType.rawValue),
                        requestId: httpResponse.value(forHTTPHeaderField: Constants.requestIdHeader),
                        body: data ?? Data(),
                        cacheDirectives: HTTPCacheDirectives(response: httpResponse)
                    )
                )
            }

            let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
            operation.networkSession = session

            return operation
        }
    }
#endif
