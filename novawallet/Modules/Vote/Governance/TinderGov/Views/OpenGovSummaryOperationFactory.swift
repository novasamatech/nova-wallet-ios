import Operation_iOS
import SubstrateSdk
import Foundation

class OpenGovSummaryOperationFactory {
    private let url: URL
    private let chain: ChainModel
    private let timeout: TimeInterval

    init(
        url: URL,
        chain: ChainModel,
        timeout: TimeInterval = 10.0
    ) {
        self.url = url
        self.chain = chain
        self.timeout = timeout
    }
}

// MARK: OpenGovSummaryOperationFactoryProtocol

extension OpenGovSummaryOperationFactory: OpenGovSummaryOperationFactoryProtocol {
    func createSummaryOperation(for referendumId: ReferendumIdLocal) -> BaseOperation<ReferendumSummary?> {
        let requestFactory = createSummaryRequestFactory(for: referendumId)
        let resultFactory = createSummaryResultFactory()

        return NetworkOperation(
            requestFactory: requestFactory,
            resultFactory: resultFactory
        )
    }
}

// MARK: Private

private extension OpenGovSummaryOperationFactory {
    func createSummaryRequestFactory(
        for referendumId: ReferendumIdLocal
    ) -> NetworkRequestFactoryProtocol {
        BlockNetworkRequestFactory { [weak self] in
            guard
                let self,
                var components = URLComponents(string: url.absoluteString)
            else {
                throw BaseOperationError.parentOperationCancelled
            }

            let referendumIdQueryItem = URLQueryItem(
                name: "postId",
                value: "\(referendumId)"
            )

            let govTypeQueryItem = URLQueryItem(
                name: "proposalType",
                value: "referendums_v2"
            )

            if let queryItems = components.queryItems {
                components.queryItems = queryItems + [referendumIdQueryItem, govTypeQueryItem]
            } else {
                components.queryItems = [referendumIdQueryItem, govTypeQueryItem]
            }

            guard let url = components.url else {
                throw BaseOperationError.parentOperationCancelled
            }

            var request = URLRequest(url: url)

            [
                HttpHeaderKey.contentType.rawValue: HttpContentType.json.rawValue,
                "x-network": chain.name.lowercased(),
                "x-ai-summary-api-key": PolkassemblyKeys.getSummaryApiKey()
            ].forEach { request.setValue($1, forHTTPHeaderField: $0) }

            request.httpMethod = HttpMethod.get.rawValue
            request.timeoutInterval = timeout
            return request
        }
    }

    func createSummaryResultFactory() -> AnyNetworkResultFactory<ReferendumSummary?> {
        AnyNetworkResultFactory<ReferendumSummary?> { data in
            try JSONDecoder().decode(ReferendumSummary.self, from: data)
        }
    }
}
