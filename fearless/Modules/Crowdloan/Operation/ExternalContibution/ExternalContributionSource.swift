import Foundation
import RobinHood

protocol ExternalContributionSourceProtocol {
    func supports(chain: ChainModel) -> Bool
    func getContributions(accountId: AccountId, chain: ChainModel) -> BaseOperation<[ExternalContribution]>
}
