import Foundation
import RobinHood
import SoraKeystore

protocol ExternalContributionSourceProtocol {
    func supports(chain: ChainModel) -> Bool
    func getContributions(accountId: AccountId, chain: ChainModel) -> BaseOperation<[ExternalContribution]>
}

enum ExternalContributionSourcesFactory {
    static func createExternalSources() -> [ExternalContributionSourceProtocol] {
        [AcalaContributionSource(), ParallelContributionSource()]
    }
}
