import Foundation
@testable import novawallet
import Operation_iOS

final class CrowdloanOffchainProviderFactoryStub: CrowdloanOffchainProviderFactoryProtocol {
    let externalContributions: [ExternalContribution]

    init(externalContributions: [ExternalContribution] = []) {
        self.externalContributions = externalContributions
    }

    func getExternalContributionProvider(
        for _: AccountId,
        chain _: ChainModel
    ) throws -> AnySingleValueProvider<[ExternalContribution]> {
        let provider = SingleValueProviderStub(item: externalContributions)
        return AnySingleValueProvider(provider)
    }
}
