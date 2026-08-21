import XCTest
@testable import novawallet
import BigInt
import Operation_iOS
import SubstrateSdk

final class HydraFeeOraclePriceTests: XCTestCase {
    func testOraclePriceForDot() {
        performOraclePriceCheck(for: 1, symbol: "DOT")
    }

    func testOraclePriceForUsdt() {
        performOraclePriceCheck(for: 9, symbol: "USDT")
    }

    func testOraclePriceForPha() {
        performOraclePriceCheck(for: 20, symbol: "PHA")
    }

    func testOraclePriceForNodl() {
        performOraclePriceCheck(for: 26, symbol: "NODL")
    }

    func testOraclePriceForEwt() {
        performOraclePriceCheck(for: 53, symbol: "EWT")
    }

    func testNonAcceptedAssetRefusesToQuote() {
        do {
            guard let chainAssetId = try performNonAcceptedAssetSearch() else {
                throw XCTSkip("every asset Nova knows about is accepted as a fee currency")
            }

            Logger.shared.info("Not accepted: \(chainAssetId)")

            XCTAssertThrowsError(try performPriceFetch(for: chainAssetId.assetId)) { error in
                guard case HydraFeeOraclePriceError.assetNotAcceptedAsFee = error else {
                    return XCTFail("Unexpected error: \(error)")
                }
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testChainBlockTimeDerivesAMirroredSmoothing() {
        do {
            let blockTime = try performBlockTimeFetch()

            Logger.shared.info("Block time: \(blockTime)ms")

            XCTAssertEqual(
                HydraEmaOracle.Smoothing.tenMinutes(blockTimeMillis: blockTime),
                Self.mirroredSmoothing[blockTime]
            )
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testMirroredStorageItemsStillExist() {
        do {
            let metadata = try performMetadataFetch()

            XCTAssertNotNil(metadata.getStorageMetadata(for: HydraEmaOracle.oraclesPath))
            XCTAssertNotNil(metadata.getStorageMetadata(for: HydraRouter.routesPath))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private extension HydraFeeOraclePriceTests {
    static let mirroredSmoothing: [BlockTime: BigUInt] = [
        6000: BigUInt("3369132345751865974884897103284833777"),
        2000: BigUInt("1130506202395144396888287732331455852")
    ]

    struct OraclePrice: CustomStringConvertible {
        let route: [HydraRouter.Trade]
        let oracle: HydraFeeConversion.Price
        let acceptedCurrency: BigUInt?

        var didFallBackToAcceptedCurrency: Bool {
            oracle.inner == acceptedCurrency
        }

        var description: String {
            "route \(route.map(\.poolName)), oracle \(oracle.inner)"
                + ", accepted currency \(acceptedCurrency.map(String.init) ?? "none")"
        }
    }

    struct Context {
        let chain: ChainModel
        let connection: ChainConnection
        let runtimeService: RuntimeProviderProtocol
        let operationQueue = OperationQueue()
    }

    func performOraclePriceCheck(for assetId: AssetModel.Id, symbol: String) {
        do {
            let price = try performOraclePriceFetch(for: assetId)

            Logger.shared.info("\(symbol): \(price)")

            XCTAssertGreaterThan(price.oracle.inner, 0)
            XCTAssertFalse(price.didFallBackToAcceptedCurrency)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func performOraclePriceFetch(for assetId: AssetModel.Id) throws -> OraclePrice {
        OraclePrice(
            route: try performRouteFetch(for: assetId),
            oracle: try performPriceFetch(for: assetId),
            acceptedCurrency: try performAcceptedCurrencyFetch(for: assetId)
        )
    }

    func performPriceFetch(for assetId: AssetModel.Id) throws -> HydraFeeConversion.Price {
        let context = try makeContext()

        let factory = HydraFeeOraclePriceFactory(
            chain: context.chain,
            connection: context.connection,
            runtimeService: context.runtimeService,
            state: HydraFeeOracleState(),
            operationQueue: context.operationQueue,
            logger: Logger.shared
        )

        return try context.run(factory.createPriceWrapper(for: context.chainAssetId(for: assetId)))
    }

    func performRouteFetch(for assetId: AssetModel.Id) throws -> [HydraRouter.Trade] {
        let context = try makeContext()
        let codingFactory = try context.runCodingFactory()
        let remoteAssetId = try context.remoteAssetId(for: assetId, codingFactory: codingFactory)
        let pair = HydraRouter.AssetPair(assetIn: remoteAssetId, assetOut: HydraDx.nativeAssetId)

        let wrapper: CompoundOperationWrapper<[StorageResponse<[HydraRouter.Trade]>]>
        wrapper = context.requestFactory().queryItems(
            engine: context.connection,
            keyParams: { [pair.ordered] },
            factory: { codingFactory },
            storagePath: HydraRouter.routesPath
        )

        let responses = try context.run(wrapper)

        return HydraFeeOraclePriceCalculator.resolveRoute(
            stored: responses.first?.value,
            assetIn: remoteAssetId,
            assetOut: HydraDx.nativeAssetId
        )
    }

    func performAcceptedCurrencyFetch(for assetId: AssetModel.Id) throws -> BigUInt? {
        let context = try makeContext()
        let codingFactory = try context.runCodingFactory()
        let remoteAssetId = try context.remoteAssetId(for: assetId, codingFactory: codingFactory)

        let wrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<BigUInt>>]>
        wrapper = context.requestFactory().queryItems(
            engine: context.connection,
            keyParams: { [StringScaleMapper(value: remoteAssetId)] },
            factory: { codingFactory },
            storagePath: HydraDx.feeCurrenciesPath
        )

        return try context.run(wrapper).first?.value?.value
    }

    func performNonAcceptedAssetSearch() throws -> ChainAssetId? {
        let context = try makeContext()

        return try context.chain.assets
            .map { context.chainAssetId(for: $0.assetId) }
            .filter { $0 != context.chain.utilityChainAssetId() }
            .first { try performAcceptedCurrencyFetch(for: $0.assetId) == nil }
    }

    func performBlockTimeFetch() throws -> BlockTime {
        guard let blockTime = try makeContext().chain.defaultBlockTimeMillis else {
            throw ChainRegistryError.noChain(KnowChainId.hydra)
        }

        return blockTime
    }

    func performMetadataFetch() throws -> RuntimeMetadataProtocol {
        try makeContext().runCodingFactory().metadata
    }

    func makeContext() throws -> Context {
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let chainId = KnowChainId.hydra

        guard
            let chain = chainRegistry.getChain(for: chainId),
            let connection = chainRegistry.getConnection(for: chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            throw ChainRegistryError.noChain(chainId)
        }

        return Context(chain: chain, connection: connection, runtimeService: runtimeService)
    }
}

private extension HydraFeeOraclePriceTests.Context {
    func chainAssetId(for assetId: AssetModel.Id) -> ChainAssetId {
        ChainAssetId(chainId: chain.chainId, assetId: assetId)
    }

    func requestFactory() -> StorageRequestFactoryProtocol {
        StorageRequestFactory.createDefault(with: operationQueue)
    }

    func run<T>(_ wrapper: CompoundOperationWrapper<T>) throws -> T {
        try withExtendedLifetime(self) {
            operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

            return try wrapper.targetOperation.extractNoCancellableResultData()
        }
    }

    func runCodingFactory() throws -> RuntimeCoderFactoryProtocol {
        try run(CompoundOperationWrapper(targetOperation: runtimeService.fetchCoderFactoryOperation()))
    }

    func remoteAssetId(
        for assetId: AssetModel.Id,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> HydraDx.AssetId {
        let chainAsset = try chain.chainAssetOrError(for: assetId)

        return try HydraDxTokenConverter.convertToRemote(
            chainAsset: chainAsset,
            codingFactory: codingFactory
        ).remoteAssetId
    }
}

private extension HydraRouter.Trade {
    var poolName: String {
        switch pool {
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
}
