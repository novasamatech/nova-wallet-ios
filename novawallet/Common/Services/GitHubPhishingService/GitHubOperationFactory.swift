import Foundation
import RobinHood
import IrohaCrypto

protocol GitHubOperationFactoryProtocol {
    func fetchPhishingListOperation(_ url: URL) -> NetworkOperation<[PhishingItem]>
    func fetchPhishingSitesOperation(_ url: URL) -> NetworkOperation<PhishingSites>
}

class GitHubOperationFactory: GitHubOperationFactoryProtocol {
    func fetchPhishingSitesOperation(_ url: URL) -> NetworkOperation<PhishingSites> {
        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )
            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<PhishingSites> { data in
            try JSONDecoder().decode(PhishingSites.self, from: data)
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        return operation
    }

    func fetchPhishingListOperation(_ url: URL) -> NetworkOperation<[PhishingItem]> {
        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )
            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<[PhishingItem]> { data in
            guard let json =
                try JSONSerialization.jsonObject(
                    with: data,
                    options: [.mutableContainers]
                ) as? [String: AnyObject]
            else {
                return []
            }

            let phishingItems = json.flatMap { (key, value) -> [PhishingItem] in
                if let publicKeys = value as? [String] {
                    let items = publicKeys.compactMap {
                        self.getPublicKey(from: $0)
                    }.map {
                        PhishingItem(source: key, publicKey: $0)
                    }
                    return items
                }
                return []
            }

            return phishingItems
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        return operation
    }

    private func getPublicKey(from address: String) -> String? {
        try? address.toAccountId().toHex()
    }
}
