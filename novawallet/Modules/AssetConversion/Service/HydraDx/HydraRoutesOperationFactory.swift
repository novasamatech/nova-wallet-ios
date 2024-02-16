import Foundation
import RobinHood
import SubstrateSdk

protocol HydraRoutesOperationFactoryProtocol {
    func createRoutesWrapper(
        for swapPair: HydraDx.LocalSwapPair
    ) -> CompoundOperationWrapper<[HydraDx.RemoteSwapRoute]>
}

final class HydraRoutesOperationFactory {
    let omnipoolTokensFactory: HydraOmnipoolTokensFactory
    let stableswapTokensFactory: HydraStableSwapsTokensFactory
    let runtimeProvider: RuntimeProviderProtocol
    let chain: ChainModel

    @Atomic(defaultValue: nil)
    private var data: HydraRoutesResolver.Data?

    init(
        chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        operationQueue: OperationQueue
    ) {
        self.chain = chain
        self.runtimeProvider = runtimeProvider

        omnipoolTokensFactory = .init(
            chain: chain,
            runtimeService: runtimeProvider,
            connection: connection,
            operationQueue: operationQueue
        )

        stableswapTokensFactory = .init(
            chain: chain,
            runtimeService: runtimeProvider,
            connection: connection,
            operationQueue: operationQueue
        )
    }

    private func createDataWrapper() -> CompoundOperationWrapper<HydraRoutesResolver.Data> {
        if let data = data {
            return CompoundOperationWrapper.createWithResult(data)
        }

        let omnipoolDirectionsWrapper = omnipoolTokensFactory.availableDirections()
        let stableswapDirectionsWrapper = stableswapTokensFactory.availableDirections()
        let stableswapPoolAssetsWrapper = stableswapTokensFactory.fetchAllLocalPoolAssets()

        let resultOperation = ClosureOperation<HydraRoutesResolver.Data> {
            let omnipoolDirections = try omnipoolDirectionsWrapper.targetOperation.extractNoCancellableResultData()
            let stableswapDirections = try stableswapDirectionsWrapper.targetOperation.extractNoCancellableResultData()
            let poolAssets = try stableswapPoolAssetsWrapper.targetOperation.extractNoCancellableResultData()

            let data = HydraRoutesResolver.Data(
                omnipoolDirections: omnipoolDirections,
                stableswapDirections: stableswapDirections,
                stableswapPoolAssets: poolAssets
            )

            self.data = data

            return data
        }

        resultOperation.addDependency(omnipoolDirectionsWrapper.targetOperation)
        resultOperation.addDependency(stableswapDirectionsWrapper.targetOperation)
        resultOperation.addDependency(stableswapPoolAssetsWrapper.targetOperation)

        let dependencies = omnipoolDirectionsWrapper.allOperations + stableswapDirectionsWrapper.allOperations +
            stableswapPoolAssetsWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: resultOperation, dependencies: dependencies)
    }

    private func createRoutesWrapper(
        for swapPair: HydraDx.LocalSwapPair,
        chain: ChainModel,
        dataOperation: BaseOperation<HydraRoutesResolver.Data>
    ) -> CompoundOperationWrapper<[HydraDx.RemoteSwapRoute]> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let resolveOperation = ClosureOperation<[HydraDx.RemoteSwapRoute]> {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            let data = try dataOperation.extractNoCancellableResultData()

            return HydraRoutesResolver.resolveRoutes(
                for: swapPair,
                data: data,
                chain: chain,
                codingFactory: codingFactory
            )
        }

        resolveOperation.addDependency(codingFactoryOperation)

        return CompoundOperationWrapper(
            targetOperation: resolveOperation,
            dependencies: [codingFactoryOperation]
        )
    }
}

extension HydraRoutesOperationFactory: HydraRoutesOperationFactoryProtocol {
    func createRoutesWrapper(
        for swapPair: HydraDx.LocalSwapPair
    ) -> CompoundOperationWrapper<[HydraDx.RemoteSwapRoute]> {
        let dataWrapper = createDataWrapper()

        let routesWrapper = createRoutesWrapper(
            for: swapPair,
            chain: chain,
            dataOperation: dataWrapper.targetOperation
        )

        routesWrapper.addDependency(wrapper: dataWrapper)

        return routesWrapper.insertingHead(operations: dataWrapper.allOperations)
    }
}
