import XCTest
@testable import novawallet
import Operation_iOS
import SubstrateSdk
import BigInt

final class HydraFeeOraclePriceTests: XCTestCase {
    private let dot = ChainAssetId(chainId: KnowChainId.hydra, assetId: 1)

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
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: SubstrateStorageTestFacade())

        guard let chain = chainRegistry.getChain(for: KnowChainId.hydra) else {
            throw ChainRegistryError.noChain(KnowChainId.hydra)
        }

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
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: SubstrateStorageTestFacade())

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: KnowChainId.hydra) else {
            throw ChainRegistryError.noChain(KnowChainId.hydra)
        }

        let operationQueue = OperationQueue()
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        operationQueue.addOperations([codingFactoryOperation], waitUntilFinished: true)

        let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

        Logger.shared.info("Hydration spec version: \(codingFactory.specVersion)")

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
    func makeFactory() throws -> (HydraFeeOraclePriceFactory, OperationQueue) {
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let chainId = KnowChainId.hydra

        guard
            let chain = chainRegistry.getChain(for: chainId),
            let connection = chainRegistry.getConnection(for: chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            throw ChainRegistryError.noChain(chainId)
        }

        let operationQueue = OperationQueue()

        let factory = HydraFeeOraclePriceFactory(
            chain: chain,
            connection: connection,
            runtimeService: runtimeService,
            operationQueue: operationQueue,
            logger: Logger.shared
        )

        return (factory, operationQueue)
    }

    func fetchPrice(for chainAssetId: ChainAssetId) throws -> HydraFeeConversion.Price {
        let (factory, operationQueue) = try makeFactory()

        let wrapper = factory.createPriceWrapper(for: chainAssetId)

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }

    func fetchAcceptedCurrencyPrice(for chainAssetId: ChainAssetId) throws -> BigUInt? {
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let chainId = chainAssetId.chainId

        guard
            let chain = chainRegistry.getChain(for: chainId),
            let connection = chainRegistry.getConnection(for: chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            throw ChainRegistryError.noChain(chainId)
        }

        let operationQueue = OperationQueue()
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let requestFactory = StorageRequestFactory.createDefault(with: operationQueue)

        let fetchWrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<BigUInt>>]>
        fetchWrapper = requestFactory.queryItems(
            engine: connection,
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

        let allOperations = [codingFactoryOperation] + fetchWrapper.allOperations

        operationQueue.addOperations(allOperations, waitUntilFinished: true)

        let responses = try fetchWrapper.targetOperation.extractNoCancellableResultData()

        return responses.first?.value?.value
    }
}
