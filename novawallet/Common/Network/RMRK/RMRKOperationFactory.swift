import Foundation
import RobinHood

protocol RMRKOperationFactoryProtocol {
    func fetchNfts(for address: AccountAddress) -> BaseOperation<[RMRKNft]>
}

final class RMRKOperationFactory: RMRKOperationFactoryProtocol {
    static let accountPath = "/account"

    let baseUrl: URL

    init(baseUrl: URL) {
        self.baseUrl = baseUrl
    }

    func fetchNfts(for address: AccountAddress) -> BaseOperation<[RMRKNft]> {
        let url = baseUrl.appendingPathComponent(Self.accountPath).appendingPathComponent(address)

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)

            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )

            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<[RMRKNft]> { data in
            return try JSONDecoder().decode([RMRKNft].self, from: data)
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }
}
