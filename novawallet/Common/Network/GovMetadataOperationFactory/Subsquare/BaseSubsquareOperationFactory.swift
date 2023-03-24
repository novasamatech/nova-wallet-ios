import Foundation
import RobinHood
import SubstrateSdk

class BaseSubsquareOperationFactory {
    let chainId: String
    let baseUrl: URL
    let timeout: TimeInterval
    let pageSize: Int

    init(baseUrl: URL, chainId: String, pageSize: Int = 1000, timeout: TimeInterval = 10) {
        self.baseUrl = baseUrl
        self.chainId = chainId
        self.pageSize = pageSize
        self.timeout = timeout
    }

    func appendingPageSize(to url: URL) -> URL {
        guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }

        urlComponents.queryItems = [URLQueryItem(name: "page_size", value: "\(pageSize)")]

        return urlComponents.url ?? url
    }

    func createPreviewUrl(from _: JSON?) -> URL {
        fatalError("Method must be implemented by child class")
    }

    func createDetailsUrl(from _: ReferendumIdLocal, parameters _: JSON?) -> URL {
        fatalError("Method must be implemented by child class")
    }

    private func createRequestFactory(
        for url: URL,
        timeout: TimeInterval
    ) -> NetworkRequestFactoryProtocol {
        BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )
            request.httpMethod = HttpMethod.get.rawValue
            request.timeoutInterval = timeout
            return request
        }
    }

    func createPreviewResultFactory(
        for chainId: ChainModel.Id
    ) -> AnyNetworkResultFactory<[ReferendumMetadataPreview]> {
        AnyNetworkResultFactory<[ReferendumMetadataPreview]> { data in
            let resultData = try JSONDecoder().decode(JSON.self, from: data)
            let items = resultData.items?.arrayValue ?? []

            return items.compactMap { remotePreview in
                let title = remotePreview.title?.stringValue

                guard let referendumId = remotePreview.referendumIndex?.unsignedIntValue else {
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

    func createDetailsResultFactory(for chainId: ChainModel.Id) -> AnyNetworkResultFactory<ReferendumMetadataLocal?> {
        AnyNetworkResultFactory<ReferendumMetadataLocal?> { data in
            let remoteDetails = try JSONDecoder().decode(JSON.self, from: data)

            let title = remoteDetails.title?.stringValue
            let content = remoteDetails.content?.stringValue

            guard let referendumId = remoteDetails.referendumIndex?.unsignedIntValue else {
                return nil
            }

            let proposer = remoteDetails.proposer?.stringValue

            let remoteTimeline = remoteDetails.onchainData?.timeline?.arrayValue

            let timeline: [ReferendumMetadataLocal.TimelineItem]?

            timeline = remoteTimeline?.compactMap { item in
                // for gov1 field called method and for gov2 - name
                let optStatus = item.method?.stringValue ?? item.name?.stringValue

                guard
                    let blockTime = item.indexer?.blockTime?.unsignedIntValue,
                    let status = optStatus else {
                    return nil
                }

                return .init(time: Date(timeIntervalSince1970: TimeInterval(blockTime).seconds), status: status)
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

extension BaseSubsquareOperationFactory: GovMetadataOperationFactoryProtocol {
    func createPreviewsOperation(for parameters: JSON?) -> BaseOperation<[ReferendumMetadataPreview]> {
        let url = createPreviewUrl(from: parameters)

        let requestFactory = createRequestFactory(for: url, timeout: timeout)
        let resultFactory = createPreviewResultFactory(for: chainId)

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func createDetailsOperation(
        for referendumId: ReferendumIdLocal,
        parameters: JSON?
    ) -> BaseOperation<ReferendumMetadataLocal?> {
        let url = createDetailsUrl(from: referendumId, parameters: parameters)

        let requestFactory = createRequestFactory(for: url, timeout: timeout)
        let resultFactory = createDetailsResultFactory(for: chainId)

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }
}
