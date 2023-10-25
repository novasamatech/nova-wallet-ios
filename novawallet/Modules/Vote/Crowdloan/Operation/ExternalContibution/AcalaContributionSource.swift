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
        let paraIdWrapper = paraIdOperationFactory.createParaIdOperation(for: acalaChainId)

        let mergeOperation = ClosureOperation<[ExternalContribution]> { [sourceName] in
            let paraId = try paraIdWrapper.targetOperation.extractNoCancellableResultData()

            return [ExternalContribution(source: sourceName, amount: 0, paraId: paraId)]
        }

        mergeOperation.addDependency(paraIdWrapper.targetOperation)

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: paraIdWrapper.allOperations)
    }
}
