import Foundation
import Foundation_iOS
import Operation_iOS
import CryptoKit

final class MercuryoRampURLFactory {
    private let actionType: RampActionType
    private let secret: String
    private let baseURL: String
    private let address: String
    private let token: String
    private let widgetId: String
    private let callBackURL: URL?

    let ipAddressProvider: IPAddressProviderProtocol
    let merchantIdFactory: MerchantTransactionIdFactoryProtocol

    init(
        actionType: RampActionType,
        secret: String,
        baseURL: String,
        address: String,
        token: String,
        widgetId: String,
        callBackURL: URL? = nil,
        ipAddressProvider: IPAddressProviderProtocol,
        merchantIdFactory: MerchantTransactionIdFactoryProtocol
    ) {
        self.actionType = actionType
        self.secret = secret
        self.baseURL = baseURL
        self.address = address
        self.token = token
        self.widgetId = widgetId
        self.callBackURL = callBackURL
        self.ipAddressProvider = ipAddressProvider
        self.merchantIdFactory = merchantIdFactory
    }
}

// MARK: - Private

private extension MercuryoRampURLFactory {
    func createBuildURLOperation(
        dependingOn ipAddressOperation: BaseOperation<String>
    ) -> BaseOperation<URL> {
        ClosureOperation<URL> { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            let ipAddress = try ipAddressOperation.extractNoCancellableResultData()
            let transactionId = merchantIdFactory.createTransactionId()

            let signatureData = [
                address,
                secret,
                ipAddress,
                transactionId
            ].joined().data(using: .utf8)

            guard let signatureData else {
                throw RampURLFactoryError.invalidURLComponents
            }

            let signaturePrefix = "v2:"
            let signature = Data(SHA512.hash(data: signatureData).makeIterator())
            let signatureWithPrefix = [signaturePrefix, signature.toHex()].joined()

            var components = URLComponents(string: baseURL)

            let type = switch actionType {
            case .onRamp: "buy"
            case .offRamp: "sell"
            }

            var queryItems = [
                URLQueryItem(name: "currency", value: token),
                URLQueryItem(name: "type", value: type),
                URLQueryItem(name: "address", value: address),
                URLQueryItem(name: "widget_id", value: widgetId),
                URLQueryItem(name: "signature", value: signatureWithPrefix)
            ]

            if let callBackURL {
                queryItems.append(URLQueryItem(name: "return_url", value: callBackURL.absoluteString))
            }

            if actionType == .offRamp {
                queryItems.append(URLQueryItem(name: "hide_refund_address", value: "true"))
                queryItems.append(URLQueryItem(name: "refund_address", value: address))
            }

            components?.queryItems = queryItems

            guard let url = components?.url else {
                throw RampURLFactoryError.invalidURLComponents
            }

            return url
        }
    }
}

// MARK: - RampURLFactory

extension MercuryoRampURLFactory: RampURLFactory {
    func createURLWrapper() -> CompoundOperationWrapper<URL> {
        let ipAddressOperation = ipAddressProvider.createIPAddressOperation()
        let buildURLOperation = createBuildURLOperation(dependingOn: ipAddressOperation)

        buildURLOperation.addDependency(ipAddressOperation)

        return CompoundOperationWrapper(
            targetOperation: buildURLOperation,
            dependencies: [ipAddressOperation]
        )
    }
}
