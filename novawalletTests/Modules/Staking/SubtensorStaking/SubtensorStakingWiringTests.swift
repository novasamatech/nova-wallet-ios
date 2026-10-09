import Cuckoo
@testable import novawallet
import Operation_iOS
import XCTest

final class SubtensorStakingWiringTests: XCTestCase {
    private let fixtureSubnet = SubtensorSubnetRef(netuid: 64, registeredAt: 4_531_295)

    func testFlowsShareTheProcessWideBackendAndLogosButOwnTheirVerifiedServices() throws {
        let chainAsset = Self.subtensorChainAsset()
        let factory = makeFactory(chain: chainAsset.chain)
        let option = Multistaking.ChainAssetOption(chainAsset: chainAsset, type: .subtensor)
        let processServices = SubtensorStakingProcessServices.shared
        let flowState = SubtensorStakingFlowState(
            coingeckoOperationFactory: CoingeckoOperationFactory(),
            operationQueue: OperationQueue()
        )

        let firstState = try factory.createSubtensorStaking(for: option, flowState: flowState)
        let secondState = try factory.createSubtensorStaking(for: option, flowState: flowState)
        let first = firstState.earnServices
        let second = secondState.earnServices

        let catalogue = try XCTUnwrap(first.catalogueService as? SubtensorSubnetCatalogueService)
        let yields = try XCTUnwrap(first.yieldService as? SubtensorYieldService)
        let recommendations = try XCTUnwrap(first.recommendationService as? SubtensorRecommendationService)
        let rankingView = try XCTUnwrap(first.rankingViewService as? SubtensorRankingViewService)
        let directory = try XCTUnwrap(first.validatorDirectoryService as? SubtensorValidatorDirectoryService)
        let secondDirectory = try XCTUnwrap(second.validatorDirectoryService as? SubtensorValidatorDirectoryService)
        let subnets = try XCTUnwrap(firstState.subnetsService as? SubtensorSubnetsService)
        let secondSubnets = try XCTUnwrap(secondState.subnetsService as? SubtensorSubnetsService)
        let priceHistory = try XCTUnwrap(first.priceHistoryService as? SubtensorPriceHistoryService)
        let secondPriceHistory = try XCTUnwrap(second.priceHistoryService as? SubtensorPriceHistoryService)
        let secondRecommendations = try XCTUnwrap(second.recommendationService as? SubtensorRecommendationService)
        let costBasis = try XCTUnwrap(processServices.costBasisService as? SubtensorCostBasisService)

        XCTAssertTrue(first.subnetLogosProvider === processServices.subnetLogosProvider)
        XCTAssertTrue(second.subnetLogosProvider === processServices.subnetLogosProvider)
        XCTAssertEqual(
            (processServices.subnetLogosProvider as? SubtensorConfigProvider)?.url,
            ApplicationConfig.shared.bittensorConfigURL
        )
        XCTAssertEqual(priceHistory.taoPriceId, chainAsset.asset.priceId)
        XCTAssertTrue(priceHistory.marketsService === processServices.subnetMarketsService)
        XCTAssertTrue(secondPriceHistory.marketsService === processServices.subnetMarketsService)
        XCTAssertTrue(priceHistory.seriesProvider === flowState.priceSeriesCache)
        XCTAssertTrue(secondPriceHistory.seriesProvider === flowState.priceSeriesCache)
        XCTAssertTrue(directory.cache === flowState.validatorDirectoryCache)
        XCTAssertTrue(secondDirectory.cache === flowState.validatorDirectoryCache)
        XCTAssertTrue(subnets.cache === flowState.subnetsInfoCache)
        XCTAssertTrue(secondSubnets.cache === flowState.subnetsInfoCache)
        XCTAssertFalse(firstState.subnetsService === secondState.subnetsService)
        XCTAssertTrue(catalogue.apiOperationFactory === processServices.bittensorApiOperationFactory)
        XCTAssertTrue(yields.apiOperationFactory === processServices.bittensorApiOperationFactory)
        XCTAssertTrue(recommendations.apiOperationFactory === processServices.bittensorApiOperationFactory)
        XCTAssertTrue(directory.apiOperationFactory === processServices.bittensorApiOperationFactory)
        XCTAssertTrue(secondRecommendations.apiOperationFactory === processServices.bittensorApiOperationFactory)
        XCTAssertTrue(costBasis.apiOperationFactory === processServices.bittensorApiOperationFactory)
        XCTAssertTrue(first.costBasisService === processServices.costBasisService)
        XCTAssertTrue(second.costBasisService === processServices.costBasisService)
        XCTAssertTrue(first.validatorChainOperationFactory is SubtensorValidatorChainOperationFactory)
        XCTAssertTrue(recommendations.chainOperationFactory === first.validatorChainOperationFactory)
        XCTAssertTrue(directory.chainOperationFactory === first.validatorChainOperationFactory)
        XCTAssertTrue(rankingView.recommendationService === first.recommendationService)
        XCTAssertFalse(first.recommendationService === second.recommendationService)
        XCTAssertFalse(first.validatorDirectoryService === second.validatorDirectoryService)
        XCTAssertFalse(first.catalogueService === second.catalogueService)
    }

    func testFixtureModeEnrichesTheDirectoryFromTheFixtureSnapshot() throws {
        let chainAsset = Self.subtensorChainAsset()
        let option = Multistaking.ChainAssetOption(chainAsset: chainAsset, type: .subtensor)

        let apiOperationFactory = BittensorApiOperationFactory(
            transport: BittensorApiFixtureTransport(),
            cache: BittensorApiResponseCache(operationQueue: OperationQueue(), logger: Logger.shared),
            logger: Logger.shared
        )

        let processServices = SubtensorStakingProcessServices(
            bittensorApiOperationFactory: apiOperationFactory,
            subnetLogosProvider: MockSubtensorSubnetLogosProviderProtocol(),
            subnetMarketsService: MockSubtensorSubnetMarketsServiceProtocol(),
            maxApyResolution: SubtensorMaxApyResolution(),
            costBasisService: SubtensorCostBasisService(
                apiOperationFactory: apiOperationFactory,
                operationQueue: OperationQueue(),
                eventCenter: EventCenter()
            ),
            isFixtureMode: true
        )

        let services = try makeFactory(chain: chainAsset.chain)
            .createSubtensorStaking(
                for: option,
                processServices: processServices,
                flowState: SubtensorStakingFlowState(
                    coingeckoOperationFactory: CoingeckoOperationFactory(),
                    operationQueue: OperationQueue()
                )
            )
            .earnServices

        let directory = try run(services.validatorDirectoryService.createDirectoryWrapper(for: fixtureSubnet))

        XCTAssertTrue(services.validatorChainOperationFactory is BittensorFixtureChainSnapshot)
        XCTAssertEqual(directory.chainBlock, BlockNumber(BittensorApiFixtureWorld.headBlock))
        XCTAssertEqual(directory.items.count, BittensorApiFixtureWorld.seatedMembers(netuid: 64).count)
        XCTAssertTrue(directory.items.allSatisfy { $0.status != nil && $0.take != nil })
    }

    func testMultistakingSyncBuildsTheSubtensorMaxApyProviderOnTheProcessWideBackend() throws {
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
        let maxApyProvider = try XCTUnwrap(updater.maxApyProvider as? SubtensorMaxApyProvider)
        let recommendations = try XCTUnwrap(maxApyProvider.recommendationService as? SubtensorRecommendationService)
        let processServices = SubtensorStakingProcessServices.shared

        XCTAssertTrue(recommendations.apiOperationFactory === processServices.bittensorApiOperationFactory)
        XCTAssertTrue(maxApyProvider.apiOperationFactory === processServices.bittensorApiOperationFactory)
        XCTAssertTrue(maxApyProvider.resolution === processServices.maxApyResolution)
        XCTAssertTrue(recommendations.chainOperationFactory is SubtensorValidatorChainOperationFactory)
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
