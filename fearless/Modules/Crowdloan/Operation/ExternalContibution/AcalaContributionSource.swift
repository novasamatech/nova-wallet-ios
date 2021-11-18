import Foundation
import RobinHood
import BigInt

final class AcalaContributionSource: ExternalContributionSourceProtocol {
    static let apiContribution = "/contribution"

    func supports(chain: ChainModel) -> Bool {
        chain.chainId == Chain.polkadot.genesisHash
    }

    func getContributions(accountId: AccountId, chain: ChainModel) -> BaseOperation<[ExternalContribution]> {
        guard let accountAddress = try? accountId.toAddress(using: chain.chainFormat) else {
            return BaseOperation.createWithError(ChainAccountFetchingError.accountNotExists)
        }

        let url = AcalaBonusService.baseURL
            .appendingPathComponent(Self.apiContribution)
            .appendingPathComponent(accountAddress)

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<[ExternalContribution]> { data in
            let resultData = try JSONDecoder().decode(
                AcalaLiquidContributionResponse.self,
                from: data
            )

            guard let amount = BigUInt(resultData.proxyAmount) else {
                throw CrowdloanBonusServiceError.internalError
            }
            return [ExternalContribution(source: "Liquid", amount: amount, paraId: 2000)]
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
        operation.requestModifier = AcalaRequestModifier()
        return operation
    }
}
