import Foundation
import Operation_iOS

typealias SwipeGovSummaryById = [ReferendumIdLocal: String]

protocol SwipeGovSummaryOperationFactoryProtocol {
    func createFetchWrapper(
        for chainId: ChainModel.Id,
        languageCode: String,
        referendumIds: Set<ReferendumIdLocal>
    ) -> CompoundOperationWrapper<SwipeGovSummaryById>
}

final class SwipeGovSummaryOperationFactory {
    let url: URL
    let timeout: TimeInterval

    init(url: URL, timeout: TimeInterval = 60) {
        self.url = url
        self.timeout = timeout
    }

    private func createFetchOperation(
        for requestParams: SwipeGovSummary.ListRequest,
        url: URL,
        timeout: TimeInterval
    ) -> NetworkOperation<SwipeGovSummary.ListResponse> {
        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url, timeoutInterval: timeout)

            request.httpBody = try JSONEncoder().encode(requestParams)
            request.httpMethod = HttpMethod.post.rawValue

            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )

            return request
        }

        let resultFactory = AnyNetworkResultFactory<SwipeGovSummary.ListResponse> { data in
            try JSONDecoder().decode(SwipeGovSummary.ListResponse.self, from: data)
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }
}

extension SwipeGovSummaryOperationFactory: SwipeGovSummaryOperationFactoryProtocol {
    func createFetchWrapper(
        for chainId: ChainModel.Id,
        languageCode: String,
        referendumIds: Set<ReferendumIdLocal>
    ) -> CompoundOperationWrapper<SwipeGovSummaryById> {
        let requestIds = referendumIds.map { String($0) }

        let request = SwipeGovSummary.ListRequest(
            chainId: chainId,
            languageIsoCode: languageCode,
            referendumIds: requestIds
        )

        let requestOperation = createFetchOperation(for: request, url: url, timeout: timeout)

        let mapOperation = ClosureOperation<SwipeGovSummaryById> {
            let results = try requestOperation.extractNoCancellableResultData()

            return results.reduce(into: SwipeGovSummaryById()) { accum, result in
                guard let referendumId = ReferendumIdLocal(result.referendumId) else {
                    return
                }

                accum[referendumId] = result.summary
            }
        }

        mapOperation.addDependency(requestOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [requestOperation])
    }
}
