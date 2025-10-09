import XCTest
@testable import novawallet
import Keystore_iOS
import Operation_iOS
import NovaCrypto

class StakingInfoTests: XCTestCase {
    func testRewardsPolkadot() throws {
        try performCalculatorServiceTest(
            address: "13mAjFVjFDpfa42k2dLdSnUyrSzK8vAySsoudnxX2EKVtfaq",
            chainId: KnowChainId.polkadot
        )
    }

    func testRewardsKusama() throws {
        try performCalculatorServiceTest(
            address: "DayVh23V32nFhvm2WojKx2bYZF1CirRgW2Jti9TXN9zaiH5",
            chainId: KnowChainId.kusama
        )
    }

    func testRewardsWestend() throws {
        try performCalculatorServiceTest(
            address: "5CDayXd3cDCWpBkSXVsVfhE5bWKyTZdD3D1XUinR1ezS1sGn",
            chainId: KnowChainId.westend
        )
    }

    // MARK: - Private

    private func performCalculatorServiceTest(
        address: String,
        chainId: ChainModel.Id
    ) throws {
        // given
        let logger = Logger.shared

        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)

        guard let chain = chainRegistry.getChain(for: chainId), let asset = chain.utilityAsset() else {
            throw ChainRegistryError.noChain(chainId)
        }

        let chainAsset = ChainAsset(chain: chain, asset: asset)

        let stakingServiceFactory = StakingServiceFactory(
            chainRegisty: chainRegistry,
            storageFacade: storageFacade,
            eventCenter: EventCenter.shared,
            operationQueue: OperationQueue(),
            logger: logger
        )

        let stakingLocalSubscriptionFactory = StakingLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: storageFacade,
            operationManager: OperationManager(),
            logger: logger
        )

        let validatorService = try stakingServiceFactory.createEraValidatorService(
            for: chainId,
            localSubscriptionFactory: stakingLocalSubscriptionFactory
        )

        let rewardCalculatorService = try stakingServiceFactory.createRewardCalculatorService(
            for: chainAsset,
            stakingType: .relaychain,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            stakingDurationFactory: BabeStakingDurationFactory(chainId: chain.chainId, chainRegistry: chainRegistry),
            validatorService: validatorService
        )

        let chainItemRepository = SubstrateRepositoryFactory(
            storageFacade: storageFacade
        ).createChainStorageItemRepository()

        let remoteStakingSubcriptionService = StakingRemoteSubscriptionService(
            chainRegistry: chainRegistry, repository: AnyDataProviderRepository(chainItemRepository),
            syncOperationManager: OperationManager(),
            repositoryOperationManager: OperationManager(),
            logger: logger
        )

        let subscriptionId = remoteStakingSubcriptionService.attachToGlobalData(
            for: chainId,
            queue: nil,
            closure: nil
        )

        // when

        validatorService.setup()
        rewardCalculatorService.setup()

        let validatorsOperation = validatorService.fetchInfoOperation()
        let calculatorOperation = rewardCalculatorService.fetchCalculatorOperation()

        let mapOperation: BaseOperation<[(String, Decimal)]> = ClosureOperation {
            let info = try validatorsOperation.extractNoCancellableResultData()
            let calculator = try calculatorOperation.extractNoCancellableResultData()

            let rewards: [(String, Decimal)] = try info.validators.map { validator in
                let reward = try calculator
                    .calculateValidatorReturn(
                        validatorAccountId: validator.accountId,
                        isCompound: false,
                        period: .year
                    )

                let address = try validator.accountId.toAddress(using: chainAsset.chain.chainFormat)
                return (address, reward * 100.0)
            }

            return rewards
        }

        mapOperation.addDependency(validatorsOperation)
        mapOperation.addDependency(calculatorOperation)

        // then

        let operationQueue = OperationQueue()
        operationQueue.addOperations(
            [validatorsOperation, calculatorOperation, mapOperation],
            waitUntilFinished: true
        )

        let result = try mapOperation.extractNoCancellableResultData()
        logger.info("Reward: \(result)")

        remoteStakingSubcriptionService.detachFromGlobalData(
            for: subscriptionId!,
            chainId: chainId,
            queue: nil,
            closure: nil
        )
    }
}
