import Cuckoo
@testable import novawallet
import Operation_iOS
import SubstrateSdk
import XCTest

final class SubtensorStakingWiringTests: XCTestCase {
    private let fixtureSubnet = SubtensorSubnetRef(netuid: 64, registeredAt: 4_531_295)

    func testFlowsShareTheProcessWideBackendAndConfigButOwnTheirVerifiedServices() throws {
        let chainAsset = Self.subtensorChainAsset()
        let factory = makeFactory(chain: chainAsset.chain)
        let option = Multistaking.ChainAssetOption(chainAsset: chainAsset, type: .subtensor)
        let processServices = SubtensorStakingProcessServices.shared

        let first = try factory.createSubtensorStaking(for: option).earnServices
        let second = try factory.createSubtensorStaking(for: option).earnServices

        let catalogue = try XCTUnwrap(first.catalogueService as? SubtensorSubnetCatalogueService)
        let yields = try XCTUnwrap(first.yieldService as? SubtensorYieldService)
        let recommendations = try XCTUnwrap(first.recommendationService as? SubtensorRecommendationService)
        let rankingView = try XCTUnwrap(first.rankingViewService as? SubtensorRankingViewService)
        let directory = try XCTUnwrap(first.validatorDirectoryService as? SubtensorValidatorDirectoryService)
        let discovery = try XCTUnwrap(first.discoveryService as? SubtensorDiscoveryService)
        let priceHistory = try XCTUnwrap(first.priceHistoryService as? SubtensorPriceHistoryService)
        let secondRecommendations = try XCTUnwrap(second.recommendationService as? SubtensorRecommendationService)

        XCTAssertTrue(first.earnConfigProvider === SubtensorStakingProcessServices.sharedEarnConfigProvider)
        XCTAssertTrue(second.earnConfigProvider === SubtensorStakingProcessServices.sharedEarnConfigProvider)
        XCTAssertTrue(directory.earnConfigProvider === SubtensorStakingProcessServices.sharedEarnConfigProvider)
        XCTAssertTrue(priceHistory.earnConfigProvider === SubtensorStakingProcessServices.sharedEarnConfigProvider)
        XCTAssertTrue(first.subnetLogosProvider === processServices.subnetLogosProvider)
        XCTAssertTrue(second.subnetLogosProvider === processServices.subnetLogosProvider)
        XCTAssertEqual(
            (processServices.subnetLogosProvider as? SubtensorSubnetLogosProvider)?.url,
            ApplicationConfig.shared.bittensorSubnetsURL
        )
        XCTAssertEqual(priceHistory.taoPriceId, chainAsset.asset.priceId)
        XCTAssertTrue(catalogue.apiOperationFactory === processServices.bittensorApiOperationFactory)
        XCTAssertTrue(yields.apiOperationFactory === processServices.bittensorApiOperationFactory)
        XCTAssertTrue(recommendations.apiOperationFactory === processServices.bittensorApiOperationFactory)
        XCTAssertTrue(directory.apiOperationFactory === processServices.bittensorApiOperationFactory)
        XCTAssertTrue(secondRecommendations.apiOperationFactory === processServices.bittensorApiOperationFactory)
        XCTAssertTrue(first.validatorChainOperationFactory is SubtensorValidatorChainOperationFactory)
        XCTAssertTrue(recommendations.chainOperationFactory === first.validatorChainOperationFactory)
        XCTAssertTrue(directory.chainOperationFactory === first.validatorChainOperationFactory)
        XCTAssertTrue(directory.recommendationService === first.recommendationService)
        XCTAssertTrue(rankingView.recommendationService === first.recommendationService)
        XCTAssertTrue(discovery.recommendationService === first.recommendationService)
        XCTAssertTrue(discovery.directoryService === first.validatorDirectoryService)
        XCTAssertTrue(discovery.yieldService === first.yieldService)
        XCTAssertFalse(first.recommendationService === second.recommendationService)
        XCTAssertFalse(first.validatorDirectoryService === second.validatorDirectoryService)
        XCTAssertFalse(first.catalogueService === second.catalogueService)
    }

    func testFixtureModeEnrichesTheDirectoryFromTheFixtureSnapshotAndPinsTheConfigPreference() throws {
        let chainAsset = Self.subtensorChainAsset()
        let option = Multistaking.ChainAssetOption(chainAsset: chainAsset, type: .subtensor)
        let configProvider = MockSubtensorEarnConfigProviderProtocol()
        let fixtureConfig = try JSONDecoder().decode(
            SubtensorEarnConfig.self,
            from: Data(SubtensorEarnConfigProvider.fixtureJSON.utf8)
        )

        stub(configProvider) { stub in
            when(stub.createConfigWrapper()).then {
                CompoundOperationWrapper.createWithResult(fixtureConfig)
            }
        }

        let processServices = SubtensorStakingProcessServices(
            bittensorApiOperationFactory: BittensorApiOperationFactory(
                transport: BittensorApiFixtureTransport(),
                cache: BittensorApiResponseCache(operationQueue: OperationQueue(), logger: Logger.shared),
                logger: Logger.shared
            ),
            earnConfigProvider: configProvider,
            subnetLogosProvider: MockSubtensorSubnetLogosProviderProtocol(),
            isFixtureMode: true
        )

        let services = try makeFactory(chain: chainAsset.chain)
            .createSubtensorStaking(for: option, processServices: processServices)
            .earnServices

        let directory = try run(services.validatorDirectoryService.createDirectoryWrapper(for: fixtureSubnet))

        let preferredHotkey = try BittensorApiFixtureWorld.validator(.ember).hotkey.toAccountId(
            using: .substrate(SubstrateConstants.genericAddressPrefix)
        )

        XCTAssertTrue(services.validatorChainOperationFactory is BittensorFixtureChainSnapshot)
        XCTAssertEqual(directory.chainBlock, BlockNumber(BittensorApiFixtureWorld.headBlock))
        XCTAssertEqual(directory.items.count, BittensorApiFixtureWorld.seatedMembers(netuid: 64).count)
        XCTAssertTrue(directory.items.allSatisfy { $0.status != nil && $0.take != nil })
        XCTAssertEqual(directory.items.filter(\.isNovaPreferred).map(\.hotkey), [preferredHotkey])
    }

    func testMultistakingSyncHandsTheProcessWideEarnConfigProviderToTheSubtensorUpdater() throws {
        let chainAsset = Self.subtensorChainAsset()
        let storageFacade = SubstrateStorageTestFacade()
        let repositoryFactory = MultistakingRepositoryFactory(storageFacade: storageFacade)
        let workingQueue = DispatchQueue(label: "test.subtensor.wiring.multistaking")

        let syncService = MultistakingSyncService(
            wallet: AccountGenerator.generateMetaAccount(),
            chainRegistry: MockChainRegistryProtocol().applyDefault(for: [chainAsset.chain]),
            providerFactory: MultistakingProviderFactory(
                repositoryFactory: repositoryFactory,
                operationQueue: OperationQueue()
            ),
            multistakingRepositoryFactory: repositoryFactory,
            substrateRepositoryFactory: SubstrateRepositoryFactory(storageFacade: storageFacade),
            offchainOperationFactory: MockMultistakingOffchainOperationFactoryProtocol(),
            operationQueue: OperationQueue(),
            workingQueue: workingQueue
        )

        workingQueue.sync {}

        let option = Multistaking.ChainAssetOption(chainAsset: chainAsset, type: .subtensor).option
        let updater = try XCTUnwrap(syncService.onchainUpdaters[option] as? SubtensorMultistakingUpdateService)

        XCTAssertTrue(updater.earnConfigProvider === SubtensorStakingProcessServices.sharedEarnConfigProvider)
    }

    private func makeFactory(chain: ChainModel) -> StakingSharedStateFactory {
        StakingSharedStateFactory(
            storageFacade: SubstrateStorageTestFacade(),
            chainRegistry: MockChainRegistryProtocol().applyDefault(for: [chain]),
            delegatedAccountSyncService: nil,
            eventCenter: EventCenter(),
            syncOperationQueue: OperationQueue(),
            repositoryOperationQueue: OperationQueue(),
            applicationConfig: ApplicationConfig.shared,
            logger: Logger.shared
        )
    }

    private func run<T>(_ wrapper: CompoundOperationWrapper<T>) throws -> T {
        let completed = expectation(description: "wrapper completed")

        wrapper.targetOperation.completionBlock = {
            completed.fulfill()
        }

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: false)

        wait(for: [completed], timeout: 10)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }

    private static func subtensorChainAsset() -> ChainAsset {
        let asset = AssetModel(
            assetId: AssetModel.utilityAssetId,
            icon: nil,
            name: "Bittensor",
            symbol: "TAO",
            precision: 9,
            priceId: "bittensor",
            stakings: [.subtensor],
            type: nil,
            typeExtras: nil,
            buyProviders: nil,
            sellProviders: nil,
            source: .remote
        )

        let chain = ChainModelGenerator.generateChain(
            assets: [asset],
            defaultChainId: KnowChainId.bittensor,
            addressPrefix: 42
        )

        return ChainAsset(chain: chain, asset: asset)
    }
}
