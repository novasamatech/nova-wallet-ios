import Foundation
import RobinHood
import SubstrateSdk

protocol PolkassemblyOperationFactoryProtocol {
    func createPreviewsOperation() -> BaseOperation<[ReferendumMetadataPreview]>

    func createDetailsOperation(
        for referendumId: ReferendumIdLocal
    ) -> BaseOperation<ReferendumMetadataLocal?>
}

class BasePolkassemblyOperationFactory {
    let chainId: ChainModel.Id
    let url: URL

    init(chainId: ChainModel.Id, url: URL) {
        self.chainId = chainId
        self.url = url
    }

    func createPreviewQuery() -> String {
        fatalError("Must be overriden by subclass")
    }

    func createDetailsQuery(for _: ReferendumIdLocal) -> String {
        fatalError("Must be overriden by subclass")
    }

    private func createRequestFactory(for url: URL, query: String) -> NetworkRequestFactoryProtocol {
        BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            let info = JSON.dictionaryValue(["query": JSON.stringValue(query)])
            request.httpBody = try JSONEncoder().encode(info)
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )
            request.httpMethod = HttpMethod.post.rawValue
            return request
        }
    }

    func createPreviewResultFactory(
        for _: ChainModel.Id
    ) -> AnyNetworkResultFactory<[ReferendumMetadataPreview]> {
        fatalError("Must be overriden by subclass")
    }

    func createDetailsResultFactory(
        for _: ChainModel.Id
    ) -> AnyNetworkResultFactory<ReferendumMetadataLocal?> {
        fatalError("Must be overriden by subclass")
    }
}

extension BasePolkassemblyOperationFactory: PolkassemblyOperationFactoryProtocol {
    func createPreviewsOperation() -> BaseOperation<[ReferendumMetadataPreview]> {
        let query = createPreviewQuery()
        let requestFactory = createRequestFactory(for: url, query: query)
        let resultFactory = createPreviewResultFactory(for: chainId)

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func createDetailsOperation(
        for referendumId: ReferendumIdLocal
    ) -> BaseOperation<ReferendumMetadataLocal?> {
        let query = createDetailsQuery(for: referendumId)
        let requestFactory = createRequestFactory(for: url, query: query)
        let resultFactory = createDetailsResultFactory(for: chainId)

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }
}
