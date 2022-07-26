import Foundation
import RobinHood
import BigInt

final class AcalaContributionSource: ExternalContributionSourceProtocol {
    static let baseUrl = URL(string: "https://crowdloan.aca-api.network")!
    static let apiContribution = "/contribution"

    let paraIdOperationFactory: ParaIdOperationFactoryProtocol
    let acalaChainId: ChainModel.Id

    init(paraIdOperationFactory: ParaIdOperationFactoryProtocol, acalaChainId: ChainModel.Id) {
        self.paraIdOperationFactory = paraIdOperationFactory
        self.acalaChainId = acalaChainId
    }

    func getContributions(accountId: AccountId, chain: ChainModel) -> CompoundOperationWrapper<[ExternalContribution]> {
        guard let accountAddress = try? accountId.toAddress(using: chain.chainFormat) else {
            return CompoundOperationWrapper.createWithError(ChainAccountFetchingError.accountNotExists)
        }

        let url = Self.baseUrl
            .appendingPathComponent(Self.apiContribution)
            .appendingPathComponent(accountAddress)

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<AcalaLiquidContributionResponse> { data in
            try JSONDecoder().decode(AcalaLiquidContributionResponse.self, from: data)
        }

        let networkOperation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        let paraIdWrapper = paraIdOperationFactory.createParaIdOperation(for: acalaChainId)

        let mergeOperation = ClosureOperation<[ExternalContribution]> {
            let response = try networkOperation.extractNoCancellableResultData()
            let paraId = try paraIdWrapper.targetOperation.extractNoCancellableResultData()

            guard let amount = BigUInt(response.proxyAmount) else {
                throw CrowdloanBonusServiceError.internalError
            }

            return [ExternalContribution(source: "Liquid", amount: amount, paraId: paraId)]
        }

        let dependencies = [networkOperation] + paraIdWrapper.allOperations
        mergeOperation.addDependency(networkOperation)
        mergeOperation.addDependency(paraIdWrapper.targetOperation)

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
    }
}
