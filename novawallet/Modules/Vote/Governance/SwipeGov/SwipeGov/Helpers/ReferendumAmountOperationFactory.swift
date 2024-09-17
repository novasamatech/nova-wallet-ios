import SubstrateSdk
import Operation_iOS
import BigInt

protocol ReferendumAmountOperationFactoryProtocol {
    func createWrapper() -> CompoundOperationWrapper<BigUInt?>
}

final class ReferendumAmountOperationFactory {
    private let referendum: ReferendumLocal
    private let connection: JSONRPCEngine
    private let runtimeProvider: RuntimeProviderProtocol
    private let actionDetailsOperationFactory: ReferendumActionOperationFactoryProtocol

    init(
        referendum: ReferendumLocal,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        actionDetailsOperationFactory: ReferendumActionOperationFactoryProtocol
    ) {
        self.referendum = referendum
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.actionDetailsOperationFactory = actionDetailsOperationFactory
    }
}

extension ReferendumAmountOperationFactory: ReferendumAmountOperationFactoryProtocol {
    func createWrapper() -> CompoundOperationWrapper<BigUInt?> {
        let wrapper = actionDetailsOperationFactory.fetchActionWrapper(
            for: referendum,
            connection: connection,
            runtimeProvider: runtimeProvider
        )

        let operation = ClosureOperation<BigUInt?> {
            let amount = try wrapper.targetOperation
                .extractNoCancellableResultData()
                .spentAmount()

            return amount
        }

        operation.addDependency(wrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: operation,
            dependencies: wrapper.allOperations
        )
    }
}
