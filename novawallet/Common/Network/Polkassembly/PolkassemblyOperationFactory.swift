import Foundation
import RobinHood
import SubstrateSdk

protocol PolkassemblyOperationFactoryProtocol {
    func createPreviewsOperation(for parameters: JSON?) -> BaseOperation<[ReferendumMetadataPreview]>

    func createDetailsOperation(
        for referendumId: ReferendumIdLocal,
        parameters: JSON?
    ) -> BaseOperation<ReferendumMetadataLocal?>
}

class BasePolkassemblyOperationFactory {
    let chainId: ChainModel.Id
    let url: URL

    init(chainId: ChainModel.Id, url: URL) {
        self.chainId = chainId
        self.url = url
    }

    func createPreviewQuery(for _: JSON?) -> String {
        fatalError("Must be overriden by subclass")
    }

    func createDetailsQuery(for _: ReferendumIdLocal, parameters _: JSON?) -> String {
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
    func createPreviewsOperation(for parameters: JSON?) -> BaseOperation<[ReferendumMetadataPreview]> {
        let query = createPreviewQuery(for: parameters)
        let requestFactory = createRequestFactory(for: url, query: query)
        let resultFactory = createPreviewResultFactory(for: chainId)

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func createDetailsOperation(
        for referendumId: ReferendumIdLocal,
        parameters: JSON?
    ) -> BaseOperation<ReferendumMetadataLocal?> {
        let query = createDetailsQuery(for: referendumId, parameters: parameters)
        let requestFactory = createRequestFactory(for: url, query: query)
        let resultFactory = createDetailsResultFactory(for: chainId)

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }
}
