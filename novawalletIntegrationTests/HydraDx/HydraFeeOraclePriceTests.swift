import XCTest
@testable import novawallet
import Operation_iOS
import SubstrateSdk
import BigInt

final class HydraFeeOraclePriceTests: XCTestCase {
    private let dot = ChainAssetId(chainId: KnowChainId.hydra, assetId: 1)

    private let mirroredSpecVersion: UInt32 = 435
    private let mirroredTenMinutesSmoothing = BigUInt("3369132345751865974884897103284833777")

    func testOraclePriceForDot() throws {
        let price = try fetchPrice(for: dot)

        Logger.shared.info("DOT fee price inner: \(price.inner)")

        XCTAssertGreaterThan(price.inner, 0)
    }

    func testOraclePriceDiffersFromFallback() throws {
        let price = try fetchPrice(for: dot)
        let fallback = try fetchAcceptedCurrencyPrice(for: dot)

        Logger.shared.info("DOT oracle: \(price.inner), accepted currency: \(String(describing: fallback))")

        XCTAssertNotNil(fallback)
        XCTAssertNotEqual(price.inner, fallback)
    }

    func testConvertedFeeHasSaneMagnitude() throws {
        let price = try fetchPrice(for: dot)

        let nativeFee = BigUInt(1_000_000_000_000) // 1 HDX
        let converted = HydraFeeConversion.convertFee(nativeFee, price: price)

        Logger.shared.info("1 HDX converts to \(converted) plancks of DOT")

        XCTAssertGreaterThan(converted, 0)
        XCTAssertLessThan(converted, nativeFee)
    }

    func testNonAcceptedAssetRefusesToQuote() throws {
        let chain = try makeEnvironment().chain

        var notAccepted: ChainAssetId?

        for asset in chain.assets {
            let chainAssetId = ChainAssetId(chainId: chain.chainId, assetId: asset.assetId)

            guard chainAssetId != chain.utilityChainAssetId() else {
                continue
            }

            if try fetchAcceptedCurrencyPrice(for: chainAssetId) == nil {
                notAccepted = chainAssetId
                break
            }
        }

        guard let notAccepted else {
            throw XCTSkip("every asset Nova knows about is currently accepted as a fee currency")
        }

        Logger.shared.info("Testing refusal for \(notAccepted)")

        XCTAssertThrowsError(try fetchPrice(for: notAccepted)) { error in
            guard case HydraFeeOraclePriceError.assetNotAcceptedAsFee = error else {
                return XCTFail("unexpected error \(error)")
            }
        }
    }

    func testRuntimeVersionIsStillTheOneWeMirrored() throws {
        let environment = try makeEnvironment()

        let codingFactory = try run(
            CompoundOperationWrapper(targetOperation: environment.runtimeService.fetchCoderFactoryOperation()),
            in: environment
        )

        Logger.shared.info("Hydration spec version: \(codingFactory.specVersion)")

        XCTAssertEqual(codingFactory.specVersion, mirroredSpecVersion)

        let blockTime = environment.chain.defaultBlockTimeMillis

        XCTAssertNotNil(blockTime)
        XCTAssertEqual(
            blockTime.flatMap { HydraEmaOracle.Smoothing.tenMinutes(blockTimeMillis: $0) },
            mirroredTenMinutesSmoothing
        )

        XCTAssertNotNil(
            codingFactory.metadata.getStorageMetadata(
                in: HydraEmaOracle.oraclesPath.moduleName,
                storageName: HydraEmaOracle.oraclesPath.itemName
            )
        )
        XCTAssertNotNil(
            codingFactory.metadata.getStorageMetadata(
                in: HydraRouter.routesPath.moduleName,
                storageName: HydraRouter.routesPath.itemName
            )
        )
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

    func fetchPrice(for chainAssetId: ChainAssetId) throws -> HydraFeeConversion.Price {
        let environment = try makeEnvironment()

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

    func fetchAcceptedCurrencyPrice(for chainAssetId: ChainAssetId) throws -> BigUInt? {
        let environment = try makeEnvironment()
        let chain = environment.chain

        let codingFactoryOperation = environment.runtimeService.fetchCoderFactoryOperation()
        let requestFactory = StorageRequestFactory.createDefault(with: environment.operationQueue)

        let fetchWrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<BigUInt>>]>
        fetchWrapper = requestFactory.queryItems(
            engine: environment.connection,
            keyParams: {
                let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
                let chainAsset = try chain.chainAssetOrError(for: chainAssetId.assetId)

                let remoteAssetId = try HydraDxTokenConverter.convertToRemote(
                    chainAsset: chainAsset,
                    codingFactory: codingFactory
                ).remoteAssetId

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
