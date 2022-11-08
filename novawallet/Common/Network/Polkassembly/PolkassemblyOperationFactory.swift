import Foundation
import RobinHood
import SubstrateSdk

protocol PolkassemblyOperationFactoryProtocol {
    func createPreviewsOperation() -> BaseOperation<[ReferendumMetadataPreview]>

    func createDetailsOperation(
        for referendumId: ReferendumIdLocal
    ) -> BaseOperation<ReferendumMetadataLocal?>
}

final class PolkassemblyChainOperationFactory {
    let chainId: ChainModel.Id
    let url: URL

    init(chainId: ChainModel.Id, url: URL) {
        self.chainId = chainId
        self.url = url
    }

    private func createPreviewQuery() -> String {
        """
        {
         posts(
             where: {type: {id: {_eq: 2}}, onchain_link: {onchain_referendum_id: {_is_null: false}}}
         ) {
             title
             onchain_link {
                onchain_referendum_id
             }
         }
        }
        """
    }

    private func createDetailsQuery(for referendumId: ReferendumIdLocal) -> String {
        """
        {
             posts(
                 where: {onchain_link: {onchain_referendum_id: {_eq: \(referendumId)}}}
             ) {
                 title
                 content
                 onchain_link {
                      onchain_referendum_id
                      proposer_address
                    onchain_referendum {
                      referendumStatus {
                        blockNumber {
                          number
                        }
                        status
                      }
                    }
                 }
             }
        }
        """
    }

    private func createRequestFactory(for url: URL, query: String) -> NetworkRequestFactoryProtocol {
        return BlockNetworkRequestFactory {
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

    private func createPreviewResultFactory(
        for chainId: ChainModel.Id
    ) -> AnyNetworkResultFactory<[ReferendumMetadataPreview]> {
        AnyNetworkResultFactory<[ReferendumMetadataPreview]> { data in
            let resultData = try JSONDecoder().decode(JSON.self, from: data)
            let nodes = resultData.data?.posts?.arrayValue ?? []

            return nodes.compactMap { remotePreview in
                let title = remotePreview.title?.stringValue

                guard let referendumId = remotePreview.onchain_link?
                    .onchain_referendum_id?.unsignedIntValue else {
                    return nil
                }

                return .init(
                    chainId: chainId,
                    referendumId: ReferendumIdLocal(referendumId),
                    title: title
                )
            }
        }
    }

    private func createDetailsResultFactory(
        for chainId: ChainModel.Id
    ) -> AnyNetworkResultFactory<ReferendumMetadataLocal?> {
        AnyNetworkResultFactory<ReferendumMetadataLocal?> { data in
            let resultData = try JSONDecoder().decode(JSON.self, from: data)
            guard let remoteDetails = resultData.data?.posts?.arrayValue?.first else {
                return nil
            }

            let title = remoteDetails.title?.stringValue
            let content = remoteDetails.content?.stringValue
            let onChainLink = remoteDetails.onchain_link

            guard let referendumId = onChainLink?.onchain_referendum_id?.unsignedIntValue else {
                return nil
            }

            let proposer = onChainLink?.proposer_address?.stringValue

            let remoteTimeline = onChainLink?.onchain_referendum?.referendumStatus?.arrayValue

            let timeline: [ReferendumMetadataLocal.TimelineItem]?
            timeline = remoteTimeline?.compactMap { item in
                guard
                    let block = item.blockNumber?.number?.unsignedIntValue,
                    let status = item.status?.stringValue else {
                    return nil
                }

                return .init(block: BlockNumber(block), status: status)
            }

            return .init(
                chainId: chainId,
                referendumId: ReferendumIdLocal(referendumId),
                title: title,
                content: content,
                proposer: proposer,
                timeline: timeline
            )
        }
    }
}

extension PolkassemblyChainOperationFactory: PolkassemblyOperationFactoryProtocol {
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
