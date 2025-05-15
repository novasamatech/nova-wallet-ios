import Foundation
import Operation_iOS

protocol RaiseAuthFactoryProtocol {
    func createAuthTokenRequest() -> CompoundOperationWrapper<RaiseAuthToken>
    func createRefreshTokenRequest(for token: String) -> BaseOperation<RaiseAuthToken>
}

final class RaiseAuthFactory {
    let keystore: RaiseAuthKeyStorageProtocol
    let operationQueue: OperationQueue
    let customerProvider: RaiseCustomerProviding

    init(
        keystore: RaiseAuthKeyStorageProtocol,
        customerProvider: RaiseCustomerProviding,
        operationQueue: OperationQueue
    ) {
        self.keystore = keystore
        self.customerProvider = customerProvider
        self.operationQueue = operationQueue
    }

    private func getBasicCredentials() throws -> String {
        try AuthCredentials.basic(for: RaiseSecret.clientId, password: RaiseSecret.secret)
    }

    private func createRequest(for endpoint: RaiseApi) throws -> URLRequest {
        var request = URLRequest(url: endpoint.url)
        request.httpMethod = endpoint.httpMethod
        request.addValue(
            HttpContentType.json.rawValue,
            forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
        )

        let customerId = try customerProvider.getCustomerId()
        request.addValue(customerId, forHTTPHeaderField: "X-CustomerID")

        let authorization = try getBasicCredentials()
        request.addValue(authorization, forHTTPHeaderField: "Authorization")
        if let body = endpoint.params {
            request.httpBody = try JSONEncoder().encode(body)
        }

        return request
    }

    private func createNonExistingClientNonceRequest() -> NetworkOperation<RaiseNonceAttributes> {
        let requestFactory = BlockNetworkRequestFactory {
            let publicKey = try self.keystore.fetchOrCreateKeypair().publicKey().rawData()
            return try self.createRequest(for: RaiseApi.createAuthentication(publicKey))
        }

        let responseFactory = RaiseAttributesResultFactory<RaiseNonceAttributes>()

        return NetworkOperation(
            requestFactory: requestFactory,
            resultFactory: AnyNetworkResultFactory(factory: responseFactory)
        )
    }

    private func createExistingClientNonceRequest() -> NetworkOperation<RaiseNonceAttributes> {
        let requestFactory = BlockNetworkRequestFactory {
            try self.createRequest(for: RaiseApi.generateNonce)
        }

        let responseFactory = RaiseAttributesResultFactory<RaiseNonceAttributes>()

        return NetworkOperation(
            requestFactory: requestFactory,
            resultFactory: AnyNetworkResultFactory(factory: responseFactory)
        )
    }

    private func createNonceRequestWrapper() -> CompoundOperationWrapper<RaiseNonceAttributes> {
        let nonExistingOperation = createNonExistingClientNonceRequest()

        let interceptingWrapper: CompoundOperationWrapper<RaiseNonceAttributes>

        interceptingWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            do {
                let result = try nonExistingOperation.extractNoCancellableResultData()
                return CompoundOperationWrapper.createWithResult(result)
            } catch let error as RaiseApiError {
                switch error.statusCode {
                case .alreadyExists:
                    let operation = self.createExistingClientNonceRequest()
                    return CompoundOperationWrapper(targetOperation: operation)
                default:
                    return CompoundOperationWrapper.createWithError(error)
                }
            } catch {
                return CompoundOperationWrapper.createWithError(error)
            }
        }

        interceptingWrapper.addDependency(operations: [nonExistingOperation])

        return interceptingWrapper.insertingHead(operations: [nonExistingOperation])
    }

    private func createVerificationRequest(
        for signedNonceClosure: @escaping () throws -> Data
    ) -> NetworkOperation<RaiseAuthToken> {
        let requestFactory = BlockNetworkRequestFactory {
            let signedNonce = try signedNonceClosure()
            return try self.createRequest(for: RaiseApi.validateVerification(signedNonce))
        }

        let responseFactory = RaiseAttributesResultFactory<RaiseAuthToken>()

        return NetworkOperation(
            requestFactory: requestFactory,
            resultFactory: AnyNetworkResultFactory(factory: responseFactory)
        )
    }
}

extension RaiseAuthFactory: RaiseAuthFactoryProtocol {
    func createAuthTokenRequest() -> CompoundOperationWrapper<RaiseAuthToken> {
        let nonceWrapper = createNonceRequestWrapper()

        let verifyOperation = createVerificationRequest {
            let nonce = try nonceWrapper.targetOperation.extractNoCancellableResultData().nonce
            return try self.keystore.sign(message: nonce)
        }

        verifyOperation.addDependency(nonceWrapper.targetOperation)

        return nonceWrapper.insertingTail(operation: verifyOperation)
    }

    func createRefreshTokenRequest(for token: String) -> BaseOperation<RaiseAuthToken> {
        let requestFactory = BlockNetworkRequestFactory {
            var request = try self.createRequest(for: RaiseApi.refreshToken)
            request.setValue(
                "Bearer \(token)",
                forHTTPHeaderField: HttpHeaderKey.authorization.rawValue
            )
            return request
        }

        let responseFactory = RaiseAttributesResultFactory<RaiseAuthToken>()

        return NetworkOperation(
            requestFactory: requestFactory,
            resultFactory: AnyNetworkResultFactory(factory: responseFactory)
        )
    }
}
