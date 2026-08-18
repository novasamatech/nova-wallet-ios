import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

protocol HydraFeeOraclePriceFactoryProtocol {
    func createPriceWrapper(
        for chainAssetId: ChainAssetId
    ) -> CompoundOperationWrapper<HydraFeeConversion.Price>
}

final class HydraFeeOraclePriceFactory {
    let chain: ChainModel
    let connection: JSONRPCEngine
    let runtimeService: RuntimeProviderProtocol
    let blockHashFactory: BlockHashOperationFactoryProtocol
    let requestFactory: StorageRequestFactoryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeService: RuntimeProviderProtocol,
        operationQueue: OperationQueue,
        blockHashFactory: BlockHashOperationFactoryProtocol = BlockHashOperationFactory(),
        requestFactory: StorageRequestFactoryProtocol? = nil,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.chain = chain
        self.connection = connection
        self.runtimeService = runtimeService
        self.blockHashFactory = blockHashFactory
        self.requestFactory = requestFactory ?? StorageRequestFactory.createDefault(with: operationQueue)
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

private extension HydraFeeOraclePriceFactory {
    struct Context {
        let codingFactory: RuntimeCoderFactoryProtocol
        let blockHash: BlockHashData
        let nativeAssetId: HydraDx.AssetId
        let hubAssetId: HydraDx.AssetId
    }

    func createAcceptedCurrencyWrapper(
        for remoteAssetId: HydraDx.AssetId,
        context: Context
    ) -> CompoundOperationWrapper<BigUInt?> {
        let fetchWrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<BigUInt>>]>
        fetchWrapper = requestFactory.queryItems(
            engine: connection,
            keyParams: { [StringScaleMapper(value: remoteAssetId)] },
            factory: { context.codingFactory },
            storagePath: HydraDx.feeCurrenciesPath,
            at: context.blockHash
        )

        let mapOperation = ClosureOperation<BigUInt?> {
            let responses = try fetchWrapper.targetOperation.extractNoCancellableResultData()

            return responses.first?.value?.value
        }

        mapOperation.addDependency(fetchWrapper.targetOperation)

        return fetchWrapper.insertingTail(operation: mapOperation)
    }

    func createBlockNumberWrapper(context: Context) -> CompoundOperationWrapper<BlockNumber> {
        let fetchWrapper: CompoundOperationWrapper<StorageResponse<StringScaleMapper<BlockNumber>>>
        fetchWrapper = requestFactory.queryItem(
            engine: connection,
            factory: { context.codingFactory },
            storagePath: SystemPallet.blockNumberPath,
            at: context.blockHash
        )

        let mapOperation = ClosureOperation<BlockNumber> {
            try fetchWrapper.targetOperation.extractNoCancellableResultData().ensureValue().value
        }

        mapOperation.addDependency(fetchWrapper.targetOperation)

        return fetchWrapper.insertingTail(operation: mapOperation)
    }

    func createRouteWrapper(
        from remoteAssetId: HydraDx.AssetId,
        context: Context
    ) -> CompoundOperationWrapper<[HydraRouter.Trade]> {
        let nativeAssetId = context.nativeAssetId
        let pair = HydraRouter.AssetPair(assetIn: remoteAssetId, assetOut: nativeAssetId).ordered

        let fetchWrapper: CompoundOperationWrapper<[StorageResponse<[HydraRouter.Trade]>]>
        fetchWrapper = requestFactory.queryItems(
            engine: connection,
            keyParams: { [pair] },
            factory: { context.codingFactory },
            storagePath: HydraRouter.routesPath,
            at: context.blockHash
        )

        let mapOperation = ClosureOperation<[HydraRouter.Trade]> {
            let responses = try fetchWrapper.targetOperation.extractNoCancellableResultData()

            return HydraFeeOraclePriceCalculator.resolveRoute(
                stored: responses.first?.value,
                assetIn: remoteAssetId,
                assetOut: nativeAssetId
            )
        }

        mapOperation.addDependency(fetchWrapper.targetOperation)

        return fetchWrapper.insertingTail(operation: mapOperation)
    }

    func createOracleEntriesWrapper(
        for legs: [HydraFeeOraclePriceCalculator.OracleLeg],
        context: Context
    ) -> CompoundOperationWrapper<[HydraEmaOracle.OracleKey: HydraEmaOracle.Entry]> {
        let keys = legs.flatMap { [$0.key(for: .tenMinutes), $0.key(for: .lastBlock)] }

        let fetchWrapper: CompoundOperationWrapper<[StorageResponse<HydraEmaOracle.StoredEntry>]>
        fetchWrapper = requestFactory.queryNMapItems(
            engine: connection,
            nParamKeys: { keys },
            factory: { context.codingFactory },
            storagePath: HydraEmaOracle.oraclesPath,
            at: context.blockHash
        )

        let mapOperation = ClosureOperation<[HydraEmaOracle.OracleKey: HydraEmaOracle.Entry]> {
            let responses = try fetchWrapper.targetOperation.extractNoCancellableResultData()

            return zip(keys, responses).reduce(into: [:]) { accum, pair in
                accum[pair.0] = pair.1.value?.entry
            }
        }

        mapOperation.addDependency(fetchWrapper.targetOperation)

        return fetchWrapper.insertingTail(operation: mapOperation)
    }

    func createOraclePriceWrapper(
        for remoteAssetId: HydraDx.AssetId,
        fallbackInner: BigUInt,
        context: Context
    ) -> CompoundOperationWrapper<HydraFeeConversion.Price> {
        let blockNumberWrapper = createBlockNumberWrapper(context: context)
        let routeWrapper = createRouteWrapper(from: remoteAssetId, context: context)

        let priceWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let parentBlock = try blockNumberWrapper.targetOperation.extractNoCancellableResultData()
            let route = try routeWrapper.targetOperation.extractNoCancellableResultData()

            let optLegs = HydraFeeOraclePriceCalculator.oracleLegs(
                for: route,
                hubAssetId: context.hubAssetId
            )

            guard let legs = optLegs, !legs.isEmpty else {
                self.logger.warning("Hydration fee: route has no oracle price, using accepted currency")

                return .createWithResult(HydraFeeConversion.Price(inner: fallbackInner))
            }

            return self.createRoutePriceWrapper(
                legs: legs,
                parentBlock: parentBlock,
                fallbackInner: fallbackInner,
                context: context
            )
        }

        priceWrapper.addDependency(wrapper: blockNumberWrapper)
        priceWrapper.addDependency(wrapper: routeWrapper)

        return priceWrapper.insertingHead(
            operations: blockNumberWrapper.allOperations + routeWrapper.allOperations
        )
    }

    func createRoutePriceWrapper(
        legs: [HydraFeeOraclePriceCalculator.OracleLeg],
        parentBlock: BlockNumber,
        fallbackInner: BigUInt,
        context: Context
    ) -> CompoundOperationWrapper<HydraFeeConversion.Price> {
        let entriesWrapper = createOracleEntriesWrapper(for: legs, context: context)

        let mapOperation = ClosureOperation<HydraFeeConversion.Price> {
            let entries = try entriesWrapper.targetOperation.extractNoCancellableResultData()

            let optPrice = HydraFeeOraclePriceCalculator.routePrice(
                legs: legs,
                entries: entries,
                parentBlock: parentBlock
            )

            guard let price = optPrice else {
                self.logger.warning("Hydration fee: oracle price unavailable, using accepted currency")

                return HydraFeeConversion.Price(inner: fallbackInner)
            }

            return price
        }

        mapOperation.addDependency(entriesWrapper.targetOperation)

        return entriesWrapper.insertingTail(operation: mapOperation)
    }

    func createGatedPriceWrapper(
        for chainAssetId: ChainAssetId,
        remoteAssetId: HydraDx.AssetId,
        context: Context
    ) -> CompoundOperationWrapper<HydraFeeConversion.Price> {
        let acceptedWrapper = createAcceptedCurrencyWrapper(for: remoteAssetId, context: context)

        let resultWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let optFallbackInner = try acceptedWrapper.targetOperation.extractNoCancellableResultData()

            guard let fallbackInner = optFallbackInner else {
                throw HydraFeeOraclePriceError.assetNotAcceptedAsFee(chainAssetId)
            }

            return self.createOraclePriceWrapper(
                for: remoteAssetId,
                fallbackInner: fallbackInner,
                context: context
            )
        }

        resultWrapper.addDependency(wrapper: acceptedWrapper)

        return resultWrapper.insertingHead(operations: acceptedWrapper.allOperations)
    }
}

extension HydraFeeOraclePriceFactory: HydraFeeOraclePriceFactoryProtocol {
    func createPriceWrapper(
        for chainAssetId: ChainAssetId
    ) -> CompoundOperationWrapper<HydraFeeConversion.Price> {
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()
        let blockHashWrapper = blockHashFactory.createBestBlockHashWrapper(connection: connection)

        let nativeAssetIdOperation = PrimitiveConstantOperation<HydraDx.AssetId>.operation(
            for: HydraDx.nativeAssetIdPath,
            dependingOn: codingFactoryOperation,
            fallbackValue: HydraDx.nativeAssetId
        )

        let hubAssetIdOperation = PrimitiveConstantOperation<HydraDx.AssetId>.operation(
            for: HydraOmnipool.hubAssetIdPath,
            dependingOn: codingFactoryOperation
        )

        nativeAssetIdOperation.addDependency(codingFactoryOperation)
        hubAssetIdOperation.addDependency(codingFactoryOperation)

        let headOperations = [codingFactoryOperation, nativeAssetIdOperation, hubAssetIdOperation]
            + blockHashWrapper.allOperations

        let priceWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let context = Context(
                codingFactory: try codingFactoryOperation.extractNoCancellableResultData(),
                blockHash: try blockHashWrapper.targetOperation.extractNoCancellableResultData(),
                nativeAssetId: try nativeAssetIdOperation.extractNoCancellableResultData(),
                hubAssetId: try hubAssetIdOperation.extractNoCancellableResultData()
            )

            let chainAsset = try self.chain.chainAssetOrError(for: chainAssetId.assetId)
            let remoteAssetId = try HydraDxTokenConverter.convertToRemote(
                chainAsset: chainAsset,
                codingFactory: context.codingFactory
            ).remoteAssetId

            guard remoteAssetId != context.nativeAssetId else {
                return .createWithResult(HydraFeeConversion.Price.one)
            }

            return self.createGatedPriceWrapper(
                for: chainAssetId,
                remoteAssetId: remoteAssetId,
                context: context
            )
        }

        headOperations.forEach { operation in
            priceWrapper.allOperations.forEach { $0.addDependency(operation) }
        }

        return priceWrapper.insertingHead(operations: headOperations)
    }
}
