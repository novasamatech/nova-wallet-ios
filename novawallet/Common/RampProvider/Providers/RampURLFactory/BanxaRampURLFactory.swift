import Foundation
import Foundation_iOS
import Operation_iOS

final class BanxaRampURLFactory {
    private let baseURL: String
    private let address: String
    private let token: String
    private let network: String

    init(
        baseURL: String,
        address: String,
        token: String,
        network: String
    ) {
        self.baseURL = baseURL
        self.address = address
        self.token = token
        self.network = network
    }
}

// MARK: - RampURLFactory

extension BanxaRampURLFactory: RampURLFactory {
    func createURLWrapper() -> CompoundOperationWrapper<URL> {
        var components = URLComponents(string: baseURL)

        let queryItems = [
            URLQueryItem(name: "coinType", value: token),
            URLQueryItem(name: "blockchain", value: network),
            URLQueryItem(name: "walletAddress", value: address)
        ]

        components?.queryItems = queryItems

        guard let url = components?.url else {
            return .createWithError(RampURLFactoryError.invalidURLComponents)
        }

        return .createWithResult(url)
    }
}
