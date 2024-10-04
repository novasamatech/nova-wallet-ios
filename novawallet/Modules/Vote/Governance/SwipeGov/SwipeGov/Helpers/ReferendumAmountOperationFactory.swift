import SubstrateSdk
import Operation_iOS
import BigInt

protocol ReferendumAmountOperationFactoryProtocol {
    func createWrapper() -> CompoundOperationWrapper<ReferendumActionLocal.Amount?>
}

final class ReferendumAmountOperationFactory {
    private let referendum: ReferendumLocal
    private let connection: JSONRPCEngine
    private let runtimeProvider: RuntimeProviderProtocol
    private let actionDetailsOperationFactory: ReferendumActionOperationFactoryProtocol
    private let spendAmountExtractor: GovSpendingExtracting

    init(
        referendum: ReferendumLocal,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        actionDetailsOperationFactory: ReferendumActionOperationFactoryProtocol,
        spendAmountExtractor: GovSpendingExtracting
    ) {
        self.referendum = referendum
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.actionDetailsOperationFactory = actionDetailsOperationFactory
        self.spendAmountExtractor = spendAmountExtractor
    }
}

extension ReferendumAmountOperationFactory: ReferendumAmountOperationFactoryProtocol {
    func createWrapper() -> CompoundOperationWrapper<ReferendumActionLocal.Amount?> {
        let wrapper = actionDetailsOperationFactory.fetchActionWrapper(
            for: referendum,
            connection: connection,
            runtimeProvider: runtimeProvider,
            spendAmountExtractor: spendAmountExtractor
        )

        let operation = ClosureOperation<ReferendumActionLocal.Amount?> {
            let amount = try wrapper.targetOperation.extractNoCancellableResultData().requestedAmount()

            return amount
        }

        operation.addDependency(wrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: operation,
            dependencies: wrapper.allOperations
        )
    }
}
