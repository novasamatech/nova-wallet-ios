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
    let state: HydraFeeOracleState
    let blockHashFactory: BlockHashOperationFactoryProtocol
    let requestFactory: StorageRequestFactoryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeService: RuntimeProviderProtocol,
        state: HydraFeeOracleState,
        operationQueue: OperationQueue,
        blockHashFactory: BlockHashOperationFactoryProtocol = BlockHashOperationFactory(),
        requestFactory: StorageRequestFactoryProtocol? = nil,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.chain = chain
        self.connection = connection
        self.runtimeService = runtimeService
        self.state = state
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
        let smoothing: BigUInt?
    }

    func createFeeCurrencyWrapper(
        for remoteAssetId: HydraDx.AssetId,
        context: Context
    ) -> CompoundOperationWrapper<HydraFeeOracleState.FeeCurrency> {
        if let cached = state.feeCurrency(for: remoteAssetId) {
            return .createWithResult(cached)
        }

        let fetchWrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<BigUInt>>]>
        fetchWrapper = requestFactory.queryItems(
            engine: connection,
            keyParams: { [StringScaleMapper(value: remoteAssetId)] },
            factory: { context.codingFactory },
            storagePath: HydraDx.feeCurrenciesPath,
            at: context.blockHash
        )

        let mapOperation = ClosureOperation<HydraFeeOracleState.FeeCurrency> {
            let responses = try fetchWrapper.targetOperation.extractNoCancellableResultData()

            let feeCurrency: HydraFeeOracleState.FeeCurrency = responses.first?.value
                .map { .accepted($0.value) } ?? .notAccepted

            self.state.store(feeCurrency: feeCurrency, for: remoteAssetId)

            return feeCurrency
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
        if let cached = state.route(for: remoteAssetId) {
            return .createWithResult(cached)
        }

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

            let route = HydraFeeOraclePriceCalculator.resolveRoute(
                stored: responses.first?.value,
                assetIn: remoteAssetId,
                assetOut: nativeAssetId
            )

            self.state.store(route: route, for: remoteAssetId)

            return route
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
        for route: [HydraRouter.Trade],
        parentBlock: BlockNumber,
        fallbackInner: BigUInt,
        context: Context
    ) -> CompoundOperationWrapper<HydraFeeConversion.Price> {
        let optLegs = HydraFeeOraclePriceCalculator.oracleLegs(
            for: route,
            hubAssetId: context.hubAssetId
        )

        guard let legs = optLegs else {
            logger.warning("Hydration fee: route has no oracle price, using accepted currency")

            return .createWithResult(HydraFeeConversion.Price(inner: fallbackInner))
        }

        guard !legs.isEmpty else {
            return .createWithResult(.one)
        }

        guard let smoothing = context.smoothing else {
            logger.warning("Hydration fee: unknown block time, using accepted currency")

            return .createWithResult(HydraFeeConversion.Price(inner: fallbackInner))
        }

        return createRoutePriceWrapper(
            legs: legs,
            parentBlock: parentBlock,
            smoothing: smoothing,
            fallbackInner: fallbackInner,
            context: context
        )
    }

    func createRoutePriceWrapper(
        legs: [HydraFeeOraclePriceCalculator.OracleLeg],
        parentBlock: BlockNumber,
        smoothing: BigUInt,
        fallbackInner: BigUInt,
        context: Context
    ) -> CompoundOperationWrapper<HydraFeeConversion.Price> {
        let entriesWrapper = createOracleEntriesWrapper(for: legs, context: context)

        let mapOperation = ClosureOperation<HydraFeeConversion.Price> {
            let entries = try entriesWrapper.targetOperation.extractNoCancellableResultData()

            let optPrice = HydraFeeOraclePriceCalculator.routePrice(
                legs: legs,
                entries: entries,
                parentBlock: parentBlock,
                smoothing: smoothing
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
        let feeCurrencyWrapper = createFeeCurrencyWrapper(for: remoteAssetId, context: context)
        let blockNumberWrapper = createBlockNumberWrapper(context: context)
        let routeWrapper = createRouteWrapper(from: remoteAssetId, context: context)

        let resultWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let feeCurrency = try feeCurrencyWrapper.targetOperation.extractNoCancellableResultData()

            guard case let .accepted(fallbackInner) = feeCurrency else {
                throw HydraFeeOraclePriceError.assetNotAcceptedAsFee(chainAssetId)
            }

            let parentBlock = try blockNumberWrapper.targetOperation.extractNoCancellableResultData()
            let route = try routeWrapper.targetOperation.extractNoCancellableResultData()

            return self.createOraclePriceWrapper(
                for: route,
                parentBlock: parentBlock,
                fallbackInner: fallbackInner,
                context: context
            )
        }

        resultWrapper.addDependency(wrapper: feeCurrencyWrapper)
        resultWrapper.addDependency(wrapper: blockNumberWrapper)
        resultWrapper.addDependency(wrapper: routeWrapper)

        return resultWrapper.insertingHead(
            operations: feeCurrencyWrapper.allOperations
                + blockNumberWrapper.allOperations
                + routeWrapper.allOperations
        )
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
                hubAssetId: try hubAssetIdOperation.extractNoCancellableResultData(),
                smoothing: self.chain.defaultBlockTimeMillis.flatMap {
                    HydraEmaOracle.Smoothing.tenMinutes(blockTimeMillis: $0)
                }
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
