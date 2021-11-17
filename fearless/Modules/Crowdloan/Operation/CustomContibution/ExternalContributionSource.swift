import Foundation
import RobinHood

protocol ExternalContributionSourceProtocol {
    func supports(chain: ChainModel) -> Bool
    func getContributions(accountAddress: AccountAddress) -> BaseOperation<ExternalContribution>
}
