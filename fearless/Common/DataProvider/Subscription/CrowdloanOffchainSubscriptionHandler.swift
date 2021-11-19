import Foundation

protocol CrowdloanOffchainSubscriptionHandler {
    func handleExternalContributions(
        result: Result<[ExternalContribution]?, Error>,
        chainId: ChainModel.Id,
        accountId: AccountId
    )
}

extension CrowdloanOffchainSubscriptionHandler {
    func handleExternalContributions(
        result _: Result<[ExternalContribution]?, Error>,
        chainId _: ChainModel.Id,
        accountId _: AccountId
    ) {}
}
