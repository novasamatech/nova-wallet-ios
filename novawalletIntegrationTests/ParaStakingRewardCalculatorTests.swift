import XCTest
@testable import novawallet
import Operation_iOS

class ParaStakingRewardCalculatorTests: XCTestCase {
    func testMaxAndAvgAprCalculation() throws {
        let chainId = "401a1f9dca3da46f5c4091016c8a2f26dcea05865116b286f60f668207d1474b"

        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)

        guard let calculator = try setupCalculator(
            for: chainId,
            storageFacade: storageFacade,
            chainRegistry: chainRegistry
        ) else {
            XCTFail("Can't construct calculator")
            return
        }

        let maxApr = calculator.calculateMaxEarnings(amount: 1.0, period: .year)

        let logger = Logger.shared

        logger.info("Max APR: \(maxApr)")
    }

    private func setupCalculator(
        for chainId: ChainModel.Id,
        storageFacade: StorageFacadeProtocol,
        chainRegistry: ChainRegistryProtocol
    ) throws -> CollatorStakingRewardCalculatorEngineProtocol? {
        guard
            let connection = chainRegistry.getConnection(for: chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId),
            let chain = chainRegistry.getChain(for: chainId),
            let assetDisplayInfo = chain.utilityAssets().first?.displayInfo else {
            return nil
        }

        let operationQueue = OperationQueue()
        let operationManager = OperationManager(operationQueue: operationQueue)
        let logger = Logger.shared

        let repositoryFactory = SubstrateRepositoryFactory(storageFacade: storageFacade)
        let repository = repositoryFactory.createChainStorageItemRepository()
        let remoteSubscription = ParachainStaking.StakingRemoteSubscriptionService(
            chainRegistry: chainRegistry,
            repository: repository,
            syncOperationManager: operationManager,
            repositoryOperationManager: operationManager,
            logger: logger
        )

        guard let subscriptionId = remoteSubscription.attachToGlobalData(
            for: chainId,
            queue: nil,
            closure: nil
        ) else {
            return nil
        }

        let providerFactory = ParachainStakingLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: storageFacade,
            operationManager: OperationManager(operationQueue: operationQueue),
            logger: logger
        )

        let collatorService = ParachainStakingCollatorService(
            chainId: chainId,
            storageFacade: storageFacade,
            runtimeCodingService: runtimeService,
            connection: connection,
            providerFactory: providerFactory,
            operationQueue: operationQueue,
            eventCenter: EventCenter.shared,
            logger: logger
        )

        collatorService.setup()

        let calculatorService = ParaStakingRewardCalculatorService(
            chainId: chainId,
            collatorsService: collatorService,
            providerFactory: providerFactory,
            connection: connection,
            runtimeCodingService: runtimeService,
            repositoryFactory: repositoryFactory,
            operationQueue: operationQueue,
            assetPrecision: assetDisplayInfo.assetPrecision,
            eventCenter: EventCenter.shared,
            logger: logger
        )

        calculatorService.setup()

        let calculatorOperation = calculatorService.fetchCalculatorOperation()

        operationQueue.addOperations([calculatorOperation], waitUntilFinished: true)

        remoteSubscription.detachFromGlobalData(
            for: subscriptionId,
            chainId: chainId,
            queue: nil,
            closure: nil
        )

        return try calculatorOperation.extractNoCancellableResultData()
    }
}
