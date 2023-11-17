import Foundation
import RobinHood
import BigInt

final class AcalaContributionSource: ExternalContributionSourceProtocol {
    var sourceName: String { "Acala Liquid" }

    let paraIdOperationFactory: ParaIdOperationFactoryProtocol
    let acalaChainId: ChainModel.Id

    init(paraIdOperationFactory: ParaIdOperationFactoryProtocol, acalaChainId: ChainModel.Id) {
        self.paraIdOperationFactory = paraIdOperationFactory
        self.acalaChainId = acalaChainId
    }

    func getContributions(
        accountId _: AccountId,
        chain _: ChainModel
    ) -> CompoundOperationWrapper<[ExternalContribution]> {
        CompoundOperationWrapper.createWithResult([])
    }
}
