import Foundation
import RobinHood
import SoraKeystore

protocol ExternalContributionSourceProtocol {
    func getContributions(accountId: AccountId, chain: ChainModel) -> BaseOperation<[ExternalContribution]>
}

enum ExternalContributionSourcesFactory {
    static func createExternalSources(for chainId: ChainModel.Id) -> [ExternalContributionSourceProtocol] {
        if chainId == Chain.polkadot.genesisHash {
            return [ParallelContributionSource(), AcalaContributionSource()]
        } else {
            return []
        }
    }
}
