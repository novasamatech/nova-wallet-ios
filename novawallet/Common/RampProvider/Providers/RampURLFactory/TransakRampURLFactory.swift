import Foundation
import Foundation_iOS
import Operation_iOS

final class TransakRampURLFactory {
    private let actionType: RampActionType
    private let pubToken: String
    private let baseURL: String
    private let address: String
    private let token: String
    private let network: String

    init(
        actionType: RampActionType,
        pubToken: String,
        baseURL: String,
        address: String,
        token: String,
        network: String
    ) {
        self.actionType = actionType
        self.pubToken = pubToken
        self.baseURL = baseURL
        self.address = address
        self.token = token
        self.network = network
    }
}

// MARK: - RampURLFactory

extension TransakRampURLFactory: RampURLFactory {
    func createURLWrapper() -> CompoundOperationWrapper<URL> {
        var components = URLComponents(string: baseURL)

        var queryItems = [
            URLQueryItem(name: "apiKey", value: pubToken),
            URLQueryItem(name: "network", value: network),
            URLQueryItem(name: "cryptoCurrencyCode", value: token)
        ]

        let productsAvailed = switch actionType {
        case .offRamp: "SELL"
        case .onRamp: "BUY"
        }

        if actionType == .onRamp {
            queryItems.append(URLQueryItem(name: "walletAddress", value: address))
            queryItems.append(URLQueryItem(name: "disableWalletAddressForm", value: "true"))
        }

        queryItems.append(URLQueryItem(name: "productsAvailed", value: productsAvailed))

        components?.queryItems = queryItems

        guard let url = components?.url else {
            return .createWithError(RampURLFactoryError.invalidURLComponents)
        }

        return .createWithResult(url)
    }
}
