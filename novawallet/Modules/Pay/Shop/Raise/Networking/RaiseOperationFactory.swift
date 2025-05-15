import Foundation
import Operation_iOS

protocol RaiseOperationFactoryProtocol {
    func createBrandsWrapper(
        for info: RaiseBrandsRequestInfo
    ) -> CompoundOperationWrapper<RaiseListResult<RaiseBrandAttributes>>

    func createCryptoAssetsWrapper() -> CompoundOperationWrapper<RaiseListResult<RaiseCryptoAssetAttributes>>

    func createTransaction(
        for info: RaiseTransactionRequestInfo
    ) -> CompoundOperationWrapper<RaiseResponse<RaiseTransactionAttributes>>

    func updateTransaction(
        for info: RaiseTransactionUpdateInfo
    ) -> CompoundOperationWrapper<RaiseResponse<RaiseTransactionAttributes>>

    func queryTransaction(
        for transactionId: String
    ) -> CompoundOperationWrapper<RaiseTransactionAttributes>

    func createCardsWrapper() -> CompoundOperationWrapper<RaiseCardsResponse>

    func getBrands(_ ids: [String]) -> CompoundOperationWrapper<RaiseListResult<RaiseBrandAttributes>>

    func getRate(
        from asset: AssetModel,
        to currency: Currency
    ) -> CompoundOperationWrapper<RaiseResponse<RaiseCryptoQuoteAttributes>>
}

final class RaiseOperationFactory {
    let authProvider: RaiseAuthProviding
    let customerProvider: RaiseCustomerProviding
    let operationQueue: OperationQueue

    init(
        authProvider: RaiseAuthProviding,
        customerProvider: RaiseCustomerProviding,
        operationQueue: OperationQueue
    ) {
        self.authProvider = authProvider
        self.customerProvider = customerProvider
        self.operationQueue = operationQueue
    }

    private func createRequestWrapper<R>(
        requestFactoryClosure: @escaping RaiseRetriableRequestClosure,
        responseFactory: BaseRaiseResultFactory<R>,
        forceTokenRefresh: Bool
    ) -> CompoundOperationWrapper<R> {
        let tokenOperation = authProvider.fetchAuthToken(forceTokenRefresh)

        let tokenClosure: RaiseAuthTokenClosure = { try tokenOperation.extractNoCancellableResultData() }
        let requestFactory = requestFactoryClosure(tokenClosure)

        let networkOperation = NetworkOperation(
            requestFactory: requestFactory,
            resultFactory: AnyNetworkResultFactory(factory: responseFactory)
        )

        networkOperation.addDependency(tokenOperation)

        return CompoundOperationWrapper(
            targetOperation: networkOperation,
            dependencies: [tokenOperation]
        )
    }

    private func createRetriableRequestWrapper<R>(
        requestFactoryClosure: @escaping RaiseRetriableRequestClosure,
        responseFactory: BaseRaiseResultFactory<R>
    ) -> CompoundOperationWrapper<R> {
        let originalWrapper = createRequestWrapper(
            requestFactoryClosure: requestFactoryClosure,
            responseFactory: responseFactory,
            forceTokenRefresh: false
        )

        let interceptingWrapper: CompoundOperationWrapper<R> = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            do {
                let response = try originalWrapper.targetOperation.extractNoCancellableResultData()
                return CompoundOperationWrapper.createWithResult(response)
            } catch let error as RaiseApiError {
                switch error.statusCode {
                case .unauthorized,
                     .forbidden:
                    return self.createRequestWrapper(
                        requestFactoryClosure: requestFactoryClosure,
                        responseFactory: responseFactory,
                        forceTokenRefresh: true
                    )
                default:
                    return CompoundOperationWrapper.createWithError(error)
                }
            } catch {
                return CompoundOperationWrapper.createWithError(error)
            }
        }

        interceptingWrapper.addDependency(wrapper: originalWrapper)

        return interceptingWrapper.insertingHead(operations: originalWrapper.allOperations)
    }

    private func createGenericRequestWrapper<R>(
        for url: URL,
        bodyParams: Encodable?,
        method: String,
        responseFactory: BaseRaiseResultFactory<R>
    ) -> CompoundOperationWrapper<R> {
        let requestFactoryClosure: RaiseRetriableRequestClosure = { tokenClosure in
            BlockNetworkRequestFactory {
                let token = try tokenClosure()

                var request = URLRequest(url: url)
                request.httpMethod = method
                request.setValue(
                    HttpContentType.json.rawValue,
                    forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
                )

                if let bodyParams {
                    request.httpBody = try JSONEncoder().encode(bodyParams)
                }

                request.setValue(
                    "Bearer \(token.token)",
                    forHTTPHeaderField: HttpHeaderKey.authorization.rawValue
                )

                return request
            }
        }

        return createRetriableRequestWrapper(
            requestFactoryClosure: requestFactoryClosure,
            responseFactory: responseFactory
        )
    }

    private func createRequestWrapper<R>(
        for endpoint: URLConvertible,
        responseFactory: BaseRaiseResultFactory<R>
    ) -> CompoundOperationWrapper<R> {
        createGenericRequestWrapper(
            for: endpoint.url,
            bodyParams: endpoint.params,
            method: endpoint.httpMethod,
            responseFactory: responseFactory
        )
    }
}

enum RaiseOperationFactoryError: Error {
    case invalidParameters
    case missingCustomer
}

extension RaiseOperationFactory: RaiseOperationFactoryProtocol {
    func createBrandsWrapper(
        for info: RaiseBrandsRequestInfo
    ) -> CompoundOperationWrapper<RaiseListResult<RaiseBrandAttributes>> {
        let factory = RaiseListResultFactory<RaiseBrandAttributes>(filter: {
            $0.transactionConfig.isSupported
        })

        return createRequestWrapper(
            for: RaiseApi.brandList(info),
            responseFactory: factory
        )
    }

    func createCardsWrapper() -> CompoundOperationWrapper<RaiseCardsResponse> {
        createRequestWrapper(
            for: RaiseApi.cards,
            responseFactory: RaiseCardsResultFactory()
        )
    }

    func createCryptoAssetsWrapper() -> CompoundOperationWrapper<RaiseListResult<RaiseCryptoAssetAttributes>> {
        createRequestWrapper(
            for: RaiseApi.cryptoAssets,
            responseFactory: RaiseListResultFactory<RaiseCryptoAssetAttributes>()
        )
    }

    func createTransaction(
        for info: RaiseTransactionRequestInfo
    ) -> CompoundOperationWrapper<RaiseResponse<RaiseTransactionAttributes>> {
        guard
            let cryptoAsset = RaiseTokensConverter().convertToCrytoAsset(from: info.paymentToken) else {
            return CompoundOperationWrapper.createWithError(RaiseOperationFactoryError.invalidParameters)
        }

        guard let customerId = try? customerProvider.getCustomerId() else {
            return CompoundOperationWrapper.createWithError(RaiseOperationFactoryError.missingCustomer)
        }

        let request = RaiseTransactionCreateAttributes(
            type: "ASYNC",
            cards: [
                .init(
                    brandId: info.brandId,
                    value: Int(info.amount),
                    quantity: 1
                )
            ],
            customer: .init(identifier: customerId),
            clientOrderId: info.orderId,
            paymentMethod: .init(
                crypto: .init(
                    asset: cryptoAsset.symbol,
                    network: cryptoAsset.network
                )
            )
        )

        return createRequestWrapper(
            for: RaiseApi.transactionCreate(request),
            responseFactory: RaiseResultFactory<RaiseTransactionAttributes>()
        )
    }

    func updateTransaction(
        for info: RaiseTransactionUpdateInfo
    ) -> CompoundOperationWrapper<RaiseResponse<RaiseTransactionAttributes>> {
        let request = RaiseTransactionUpdateAttributes(
            cards: [
                RaiseTransactionCreateAttributes.Card(
                    brandId: info.brandId,
                    value: Int(info.amount),
                    quantity: 1
                )
            ]
        )

        return createRequestWrapper(
            for: RaiseApi.transactionUpdate(info.transactionId, request),
            responseFactory: RaiseResultFactory<RaiseTransactionAttributes>()
        )
    }

    func queryTransaction(
        for transactionId: String
    ) -> CompoundOperationWrapper<RaiseTransactionAttributes> {
        createRequestWrapper(
            for: RaiseApi.transaction(transactionId),
            responseFactory: RaiseAttributesResultFactory<RaiseTransactionAttributes>()
        )
    }

    func getBrands(_ ids: [String]) -> CompoundOperationWrapper<RaiseListResult<RaiseBrandAttributes>> {
        let factory = RaiseListResultFactory<RaiseBrandAttributes>(filter: {
            $0.transactionConfig.isSupported
        })
        return createRequestWrapper(
            for: RaiseApi.brands(ids),
            responseFactory: factory
        )
    }

    func getRate(
        from asset: AssetModel,
        to currency: Currency
    ) -> CompoundOperationWrapper<RaiseResponse<RaiseCryptoQuoteAttributes>> {
        createRequestWrapper(
            for: RaiseApi.rate(from: asset, toCurrency: currency),
            responseFactory: RaiseResultFactory<RaiseCryptoQuoteAttributes>()
        )
    }
}

private extension RaiseBrandAttributes.TransactionConfig {
    var isSupported: Bool {
        switch self {
        case .variableLoad:
            true
        case .fixedLoad:
            false
        }
    }
}
