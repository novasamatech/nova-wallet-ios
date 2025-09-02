import Foundation
import SubstrateSdk
import Operation_iOS

protocol PolkadotInflationPredictionFactoryProtocol {
    func createPredictionWrapper(
        for connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        at block: BlockHash?
    ) -> CompoundOperationWrapper<RuntimeApiInflationPrediction>
}

extension PolkadotInflationPredictionFactoryProtocol {
    func createPredictionWrapper(
        for connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<RuntimeApiInflationPrediction> {
        createPredictionWrapper(
            for: connection,
            runtimeProvider: runtimeProvider,
            at: nil
        )
    }
}

final class PolkadotInflationPredictionFactory {
    let operationQueue: OperationQueue
    let stateCallFactory: StateCallRequestFactoryProtocol

    init(stateCallFactory: StateCallRequestFactoryProtocol, operationQueue: OperationQueue) {
        self.stateCallFactory = stateCallFactory
        self.operationQueue = operationQueue
    }
}

private extension PolkadotInflationPredictionFactory {
    func createPredictionWrapper(
        for connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        stateCallFactory: StateCallRequestFactoryProtocol,
        at block: BlockHash?
    ) -> CompoundOperationWrapper<RuntimeApiInflationPrediction> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let fetchWrapper = OperationCombiningService<RuntimeApiInflationPrediction>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            let runtimeApi = try codingFactory.metadata.getRuntimeApiMethodOrError(
                for: "Inflation",
                methodName: "experimental_inflation_prediction_info"
            )

            return stateCallFactory.createWrapper(
                for: runtimeApi.callName,
                paramsClosure: nil,
                codingFactoryClosure: { codingFactory },
                connection: connection,
                queryType: String(runtimeApi.method.output),
                at: block
            )
        }

        fetchWrapper.addDependency(operations: [codingFactoryOperation])

        return fetchWrapper.insertingHead(operations: [codingFactoryOperation])
    }
}

extension PolkadotInflationPredictionFactory: PolkadotInflationPredictionFactoryProtocol {
    func createPredictionWrapper(
        for connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        at block: BlockHash?
    ) -> CompoundOperationWrapper<RuntimeApiInflationPrediction> {
        createPredictionWrapper(
            for: connection,
            runtimeProvider: runtimeProvider,
            stateCallFactory: stateCallFactory,
            at: block
        )
    }
}
