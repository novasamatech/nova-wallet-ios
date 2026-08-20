import XCTest
@testable import novawallet
import Operation_iOS
import SubstrateSdk
import BigInt

final class HydraFeeOraclePriceTests: XCTestCase {
    private let dot = ChainAssetId(chainId: KnowChainId.hydra, assetId: 1)

    // DOT alone routes through aave and omnipool only, so it never touches the stableswap or xyk
    // arms of oracleLegs. These are picked to spread across the remaining pool types.
    private let sampledFeeAssets: [(symbol: String, assetId: AssetModel.Id)] = [
        ("DOT", 1),
        ("USDT", 9),
        ("PHA", 20),
        ("NODL", 26),
        ("EWT", 53)
    ]

    // pallet-ema-oracle hardcodes into_smoothing() and rebases the whole table whenever
    // MILLISECS_PER_BLOCK changes, so pin the block time to its constant rather than a spec version:
    // a routine runtime upgrade must not fail this, but a block time we have never mirrored must.
    private let palletTenMinutesSmoothing: [BlockTime: BigUInt] = [
        6000: BigUInt("3369132345751865974884897103284833777"), // hydration-node <= v50.0.2, spec 435
        2000: BigUInt("1130506202395144396888287732331455852") // hydration-node >= v51.0.0, spec 440
    ]

    func testOraclePriceForDot() throws {
        let environment = try makeEnvironment()
        let price = try fetchPrice(for: dot, in: environment)

        let nativeFee = BigUInt(1_000_000_000_000) // 1 HDX
        let converted = HydraFeeConversion.convertFee(nativeFee, price: price)

        Logger.shared.info("DOT fee price inner: \(price.inner), 1 HDX converts to \(converted) plancks")

        XCTAssertGreaterThan(price.inner, 0)
        XCTAssertGreaterThan(converted, 0)
    }

    func testOraclePriceDoesNotDegradeToTheFallback() throws {
        let environment = try makeEnvironment()

        let price = try fetchPrice(for: dot, in: environment)
        let optFallback = try fetchAcceptedCurrencyPrice(for: dot, in: environment)

        guard let fallback = optFallback else {
            return XCTFail("DOT is expected to be an accepted fee currency")
        }

        Logger.shared.info(
            "DOT oracle: \(price.inner), accepted currency: \(fallback), \(ratio(price.inner, fallback))x"
        )

        XCTAssertNotEqual(price.inner, fallback)
    }

    func testEverySampledFeeAssetPricesFromTheOracle() throws {
        let environment = try makeEnvironment()

        var observedPools: Set<String> = []
        var priced = 0

        for sample in sampledFeeAssets {
            let chainAssetId = ChainAssetId(chainId: KnowChainId.hydra, assetId: sample.assetId)

            guard let fallback = try fetchAcceptedCurrencyPrice(for: chainAssetId, in: environment) else {
                Logger.shared.warning("\(sample.symbol) is not an accepted fee currency, skipping")
                continue
            }

            let route = try fetchRoute(for: chainAssetId, in: environment)
            let pools = route.map(poolName)
            let price = try fetchPrice(for: chainAssetId, in: environment)

            Logger.shared.info(
                "\(sample.symbol): route \(pools), oracle \(price.inner), "
                    + "fallback \(fallback), \(ratio(price.inner, fallback))x"
            )

            observedPools.formUnion(pools)

            guard !pools.contains(HydraRouter.PoolType.lbpField), !pools.contains(HydraRouter.PoolType.hsmField) else {
                // The runtime cannot price these either, so the accepted-currency price is correct here
                XCTAssertEqual(price.inner, fallback, "\(sample.symbol) should fall back on an lbp/hsm hop")
                continue
            }

            XCTAssertNotEqual(price.inner, fallback, "\(sample.symbol) silently degraded to the fallback")

            priced += 1
        }

        XCTAssertGreaterThan(priced, 0)

        // A wrong Source constant or stableswap pivot only shows up on a route that uses them
        for pool in [HydraRouter.PoolType.stableswapField, HydraRouter.PoolType.xykField] {
            if !observedPools.contains(pool) {
                Logger.shared.warning("no sampled asset currently routes through \(pool), coverage is incomplete")
            }
        }
    }

    func testNonAcceptedAssetRefusesToQuote() throws {
        let environment = try makeEnvironment()
        let chain = environment.chain

        var notAccepted: ChainAssetId?

        for asset in chain.assets {
            let chainAssetId = ChainAssetId(chainId: chain.chainId, assetId: asset.assetId)

            guard chainAssetId != chain.utilityChainAssetId() else {
                continue
            }

            if try fetchAcceptedCurrencyPrice(for: chainAssetId, in: environment) == nil {
                notAccepted = chainAssetId
                break
            }
        }

        guard let notAccepted else {
            throw XCTSkip("every asset Nova knows about is currently accepted as a fee currency")
        }

        Logger.shared.info("Testing refusal for \(notAccepted)")

        XCTAssertThrowsError(try fetchPrice(for: notAccepted, in: environment)) { error in
            guard case HydraFeeOraclePriceError.assetNotAcceptedAsFee = error else {
                return XCTFail("unexpected error \(error)")
            }
        }
    }

    func testChainConfigDerivesAShippedPalletSmoothing() throws {
        let environment = try makeEnvironment()

        let codingFactory = try run(
            CompoundOperationWrapper(targetOperation: environment.runtimeService.fetchCoderFactoryOperation()),
            in: environment
        )

        Logger.shared.info("Hydration spec version: \(codingFactory.specVersion)")

        guard let blockTime = environment.chain.defaultBlockTimeMillis else {
            return XCTFail("the fee oracle needs additional.defaultBlockTime to derive the smoothing")
        }

        guard let expected = palletTenMinutesSmoothing[blockTime] else {
            return XCTFail(
                "chain config reports \(blockTime)ms per block, which no mirrored pallet table covers "
                    + "- re-check into_smoothing() for this runtime"
            )
        }

        XCTAssertEqual(HydraEmaOracle.Smoothing.tenMinutes(blockTimeMillis: blockTime), expected)
    }

    func testMirroredStorageItemsStillExist() throws {
        let environment = try makeEnvironment()

        let codingFactory = try run(
            CompoundOperationWrapper(targetOperation: environment.runtimeService.fetchCoderFactoryOperation()),
            in: environment
        )

        for path in [HydraEmaOracle.oraclesPath, HydraRouter.routesPath] {
            XCTAssertNotNil(
                codingFactory.metadata.getStorageMetadata(
                    in: path.moduleName,
                    storageName: path.itemName
                ),
                "\(path.moduleName).\(path.itemName) is gone from the runtime"
            )
        }
    }
}

private extension HydraFeeOraclePriceTests {
    struct Environment {
        let chainRegistry: ChainRegistryProtocol
        let chain: ChainModel
        let connection: ChainConnection
        let runtimeService: RuntimeProviderProtocol
        let operationQueue: OperationQueue
    }

    func makeEnvironment() throws -> Environment {
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let chainId = KnowChainId.hydra

        guard
            let chain = chainRegistry.getChain(for: chainId),
            let connection = chainRegistry.getConnection(for: chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            throw ChainRegistryError.noChain(chainId)
        }

        return Environment(
            chainRegistry: chainRegistry,
            chain: chain,
            connection: connection,
            runtimeService: runtimeService,
            operationQueue: OperationQueue()
        )
    }

    func run<T>(
        _ wrapper: CompoundOperationWrapper<T>,
        in environment: Environment
    ) throws -> T {
        try withExtendedLifetime(environment) {
            environment.operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

            return try wrapper.targetOperation.extractNoCancellableResultData()
        }
    }

    func ratio(_ price: BigUInt, _ fallback: BigUInt) -> Double {
        guard fallback > 0 else {
            return .nan
        }

        return Double(price.description)! / Double(fallback.description)!
    }

    func poolName(for trade: HydraRouter.Trade) -> String {
        switch trade.pool {
        case .xyk:
            return HydraRouter.PoolType.xykField
        case .lbp:
            return HydraRouter.PoolType.lbpField
        case .stableswap:
            return HydraRouter.PoolType.stableswapField
        case .omnipool:
            return HydraRouter.PoolType.omnipoolField
        case .aave:
            return HydraRouter.PoolType.aaveField
        case .hsm:
            return HydraRouter.PoolType.hsmField
        }
    }

    func fetchPrice(
        for chainAssetId: ChainAssetId,
        in environment: Environment
    ) throws -> HydraFeeConversion.Price {
        let factory = HydraFeeOraclePriceFactory(
            chain: environment.chain,
            connection: environment.connection,
            runtimeService: environment.runtimeService,
            state: HydraFeeOracleState(),
            operationQueue: environment.operationQueue,
            logger: Logger.shared
        )

        return try run(factory.createPriceWrapper(for: chainAssetId), in: environment)
    }

    func fetchRoute(
        for chainAssetId: ChainAssetId,
        in environment: Environment
    ) throws -> [HydraRouter.Trade] {
        let codingFactory = try run(
            CompoundOperationWrapper(targetOperation: environment.runtimeService.fetchCoderFactoryOperation()),
            in: environment
        )

        let remoteAssetId = try Self.remoteAssetId(
            for: chainAssetId,
            chain: environment.chain,
            codingFactory: codingFactory
        )

        let pair = HydraRouter.AssetPair(assetIn: remoteAssetId, assetOut: HydraDx.nativeAssetId)
        let requestFactory = StorageRequestFactory.createDefault(with: environment.operationQueue)

        let fetchWrapper: CompoundOperationWrapper<[StorageResponse<[HydraRouter.Trade]>]>
        fetchWrapper = requestFactory.queryItems(
            engine: environment.connection,
            keyParams: { [pair.ordered] },
            factory: { codingFactory },
            storagePath: HydraRouter.routesPath
        )

        let responses = try run(fetchWrapper, in: environment)

        return HydraFeeOraclePriceCalculator.resolveRoute(
            stored: responses.first?.value,
            assetIn: remoteAssetId,
            assetOut: HydraDx.nativeAssetId
        )
    }

    static func remoteAssetId(
        for chainAssetId: ChainAssetId,
        chain: ChainModel,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> HydraDx.AssetId {
        let chainAsset = try chain.chainAssetOrError(for: chainAssetId.assetId)

        return try HydraDxTokenConverter.convertToRemote(
            chainAsset: chainAsset,
            codingFactory: codingFactory
        ).remoteAssetId
    }

    func fetchAcceptedCurrencyPrice(
        for chainAssetId: ChainAssetId,
        in environment: Environment
    ) throws -> BigUInt? {
        let chain = environment.chain
        let codingFactoryOperation = environment.runtimeService.fetchCoderFactoryOperation()
        let requestFactory = StorageRequestFactory.createDefault(with: environment.operationQueue)

        let fetchWrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<BigUInt>>]>
        fetchWrapper = requestFactory.queryItems(
            engine: environment.connection,
            keyParams: {
                let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
                let remoteAssetId = try Self.remoteAssetId(
                    for: chainAssetId,
                    chain: chain,
                    codingFactory: codingFactory
                )

                return [StringScaleMapper(value: remoteAssetId)]
            },
            factory: { try codingFactoryOperation.extractNoCancellableResultData() },
            storagePath: HydraDx.feeCurrenciesPath
        )

        fetchWrapper.addDependency(operations: [codingFactoryOperation])

        let responses = try run(
            fetchWrapper.insertingHead(operations: [codingFactoryOperation]),
            in: environment
        )

        return responses.first?.value?.value
    }
}
