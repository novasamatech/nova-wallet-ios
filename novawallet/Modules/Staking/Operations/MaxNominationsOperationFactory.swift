import Foundation
import BigInt
import Operation_iOS
import SubstrateSdk

protocol MaxNominationsOperationFactoryProtocol {
    func createNominationsQuotaWrapper(
        for amount: BigUInt,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<UInt32>
}

final class MaxNominationsOperationFactory {
    static var quotaBuiltIn: String { "StakingApi_nominations_quota" }

    let fallbackNominations: UInt32
    let stateCallFactory: StateCallRequestFactoryProtocol
    let operationQueue: OperationQueue

    init(
        operationQueue: OperationQueue,
        stateCallFactory: StateCallRequestFactoryProtocol = StateCallRequestFactory(),
        fallbackNominations: UInt32 = SubstrateConstants.maxNominations
    ) {
        self.operationQueue = operationQueue
        self.stateCallFactory = stateCallFactory
        self.fallbackNominations = fallbackNominations
    }

    private func constantFetchOperation(
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> BaseOperation<UInt32> {
        let constOperation = PrimitiveConstantOperation<UInt32>(oneOfPaths: [Staking.maxNominationsPath])

        constOperation.configurationBlock = {
            do {
                constOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                constOperation.result = .failure(error)
            }
        }

        return constOperation
    }

    private func createRpcWrapper(
        for amount: BigUInt,
        connection: JSONRPCEngine,
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> CompoundOperationWrapper<UInt32> {
        let wrapper: CompoundOperationWrapper<StringScaleMapper<UInt32>> = stateCallFactory.createWrapper(
            for: Self.quotaBuiltIn,
            paramsClosure: { encoder, context in
                try encoder.append(
                    StringScaleMapper(value: amount),
                    ofType: KnownType.balance.name,
                    with: context.toRawContext()
                )
            },
            codingFactoryClosure: { codingFactory },
            connection: connection,
            queryType: PrimitiveType.u32.name
        )

        let mapOperation = ClosureOperation<UInt32> {
            try wrapper.targetOperation.extractNoCancellableResultData().value
        }

        mapOperation.addDependency(wrapper.targetOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: wrapper.allOperations)
    }

    private func rpcFetchOperation(
        for amount: BigUInt,
        connection: JSONRPCEngine,
        constantFetchOperation: BaseOperation<UInt32>,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        fallbackValue: UInt32
    ) -> CompoundOperationWrapper<UInt32> {
        let combiningOperation = OperationCombiningService(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            if let value = try? constantFetchOperation.extractNoCancellableResultData() {
                let wrapper = CompoundOperationWrapper.createWithResult(value)
                return [wrapper]
            } else {
                let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

                let wrapper = self.createRpcWrapper(
                    for: amount,
                    connection: connection,
                    codingFactory: codingFactory
                )

                return [wrapper]
            }
        }.longrunOperation()

        let mappingOperation = ClosureOperation<UInt32> {
            do {
                return try combiningOperation.extractNoCancellableResultData().first ?? fallbackValue
            } catch {
                return fallbackValue
            }
        }

        mappingOperation.addDependency(combiningOperation)

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: [combiningOperation])
    }
}

extension MaxNominationsOperationFactory: MaxNominationsOperationFactoryProtocol {
    func createNominationsQuotaWrapper(
        for amount: BigUInt,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<UInt32> {
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let constantFetchOperation = constantFetchOperation(dependingOn: codingFactoryOperation)
        constantFetchOperation.addDependency(codingFactoryOperation)

        let rpcWrapper = rpcFetchOperation(
            for: amount,
            connection: connection,
            constantFetchOperation: constantFetchOperation,
            codingFactoryOperation: codingFactoryOperation,
            fallbackValue: fallbackNominations
        )

        rpcWrapper.addDependency(operations: [constantFetchOperation])

        let dependencies = [codingFactoryOperation, constantFetchOperation] + rpcWrapper.dependencies

        return CompoundOperationWrapper(
            targetOperation: rpcWrapper.targetOperation,
            dependencies: dependencies
        )
    }
}
