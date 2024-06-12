import Foundation
import Operation_iOS
import SoraKeystore

protocol ExternalContributionSourceProtocol {
    var sourceName: String { get }
    func getContributions(accountId: AccountId, chain: ChainModel) -> CompoundOperationWrapper<[ExternalContribution]>
}

enum ExternalContributionSourcesFactory {
    static func createExternalSources(
        for chainId: ChainModel.Id,
        paraIdOperationFactory: ParaIdOperationFactoryProtocol
    ) -> [ExternalContributionSourceProtocol] {
        if chainId == KnowChainId.polkadot {
            return [
                ParallelContributionSource(),
                AcalaContributionSource(
                    paraIdOperationFactory: paraIdOperationFactory,
                    acalaChainId: KnowChainId.acala
                )
            ]
        } else {
            return []
        }
    }
}
