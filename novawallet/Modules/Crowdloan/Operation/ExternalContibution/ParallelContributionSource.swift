import Foundation
import RobinHood

final class ParallelContributionSource: ExternalContributionSourceProtocol {
    static let baseURL = URL(string: "https://auction-service-prod.parallel.fi/crowdloan/rewards")!

    func getContributions(accountId: AccountId, chain: ChainModel) -> CompoundOperationWrapper<[ExternalContribution]> {
        guard let accountAddress = try? accountId.toAddress(using: chain.chainFormat) else {
            return CompoundOperationWrapper.createWithError(ChainAccountFetchingError.accountNotExists)
        }

        let url = Self.baseURL
            .appendingPathComponent(chain.name.lowercased())
            .appendingPathComponent(accountAddress)

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<[ExternalContribution]> { data in
            let resultData = try JSONDecoder().decode(
                [ParallelContributionResponse].self,
                from: data
            )

            return resultData.map { ExternalContribution(source: "Parallel", amount: $0.amount, paraId: $0.paraId) }
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
