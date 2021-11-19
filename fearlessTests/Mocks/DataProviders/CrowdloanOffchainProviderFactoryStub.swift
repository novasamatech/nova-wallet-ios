import Foundation
@testable import fearless
import RobinHood

final class CrowdloanOffchainProviderFactoryStub: CrowdloanOffchainProviderFactoryProtocol {
    let externalContributions: [ExternalContribution]

    init(externalContributions: [ExternalContribution] = []) {
        self.externalContributions = externalContributions
    }

    func getExternalContributionProvider(
        for accountId: AccountId,
        chain: ChainModel
    ) throws -> AnySingleValueProvider<[ExternalContribution]> {
        let provider = SingleValueProviderStub(item: externalContributions)
        return AnySingleValueProvider(provider)
    }
}
