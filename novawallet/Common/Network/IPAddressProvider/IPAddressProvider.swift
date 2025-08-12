import Foundation
import Operation_iOS

protocol IPAddressProviderProtocol {
    func createIPAddressOperation() -> BaseOperation<String>
}

final class IPAddressProvider: IPAddressProviderProtocol {
    func createIPAddressOperation() -> BaseOperation<String> {
        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: Constants.ipAddressURL)
            request.httpMethod = HttpMethod.get.rawValue
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )

            return request
        }

        let responseFactory = AnyNetworkResultFactory<String> { data in
            guard let address = String(data: data, encoding: .utf8) else {
                throw IPAddressProviderError.unexpectedResponse
            }

            return address
        }

        return NetworkOperation(
            requestFactory: requestFactory,
            resultFactory: responseFactory
        )
    }
}

private extension IPAddressProvider {
    enum Constants {
        static let ipAddressURL = URL(string: "https://api.ipify.org")!
    }

    enum IPAddressProviderError: Error {
        case unexpectedResponse
    }
}
