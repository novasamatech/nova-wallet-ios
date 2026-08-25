import XCTest
@testable import novawallet
import BigInt
import Operation_iOS
import SubstrateSdk

final class SubtensorStakingApiTests: XCTestCase {
    private var context: Context!

    override func setUpWithError() throws {
        context = try Self.sharedContext.get()
    }

    func testAllDynamicInfoDecodesWithRootSubnet() {
        do {
            let dynamicInfoList = try context.fetchDynamicInfoList()

            Logger.shared.info("Subnets: \(dynamicInfoList.count)")

            XCTAssertFalse(dynamicInfoList.isEmpty)

            let netuids = dynamicInfoList.map(\.netuid)
            XCTAssertEqual(Set(netuids).count, netuids.count)

            let root = dynamicInfoList.first { $0.netuid == SubtensorStakingPallet.rootNetuid }
            XCTAssertFalse(try XCTUnwrap(root).displayName.isEmpty)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAlphaPricesArePositiveWithRootPinnedToPriceScale() {
        do {
            let prices = try context.fetchAlphaPrices()

            Logger.shared.info("Prices: \(prices.count)")

            XCTAssertFalse(prices.isEmpty)

            for price in prices {
                XCTAssertGreaterThan(price.price, 0, "netuid \(price.netuid)")
            }

            let rootPrice = try XCTUnwrap(prices.first { $0.netuid == SubtensorStakingPallet.rootNetuid })
            XCTAssertEqual(rootPrice.price, SubtensorStakingPallet.alphaPriceScale)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAlphaPricesCoverSameSubnetsAsDynamicInfo() {
        do {
            let dynamicNetuids = Set(try context.fetchDynamicInfoList().map(\.netuid))
            let priceNetuids = Set(try context.fetchAlphaPrices().map(\.netuid))

            XCTAssertEqual(dynamicNetuids, priceNetuids)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDelegatesDecodeWithTakesWithinUnitInterval() {
        do {
            let delegates = try context.fetchDelegates()

            Logger.shared.info("Delegates: \(delegates.count)")

            XCTAssertFalse(delegates.isEmpty)

            for delegate in delegates {
                let take = Decimal(delegate.take) / Decimal(UInt16.max)

                XCTAssertGreaterThanOrEqual(take, 0, "delegate \(delegate.delegateSs58.toHex())")
                XCTAssertLessThanOrEqual(take, 1, "delegate \(delegate.delegateSs58.toHex())")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testStakeInfoForDiscoveredStakerHasPositiveTotals() {
        do {
            let coldkey = try context.discoverStakedColdkey()

            Logger.shared.info("Discovered staker: \(coldkey.toHex())")

            let stakeInfoList = try context.run(context.apiFactory.createStakeInfoWrapper(for: coldkey))

            XCTAssertFalse(stakeInfoList.isEmpty)

            let totalStake = stakeInfoList.reduce(Balance(0)) { $0 + $1.stake }
            XCTAssertGreaterThan(totalStake, 0)

            let knownNetuids = Set(try context.fetchDynamicInfoList().map(\.netuid))

            for stakeInfo in stakeInfoList {
                XCTAssertEqual(stakeInfo.coldkey, coldkey)
                XCTAssertTrue(knownNetuids.contains(stakeInfo.netuid), "netuid \(stakeInfo.netuid)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private extension SubtensorStakingApiTests {
    static let chainId = "2f0555cc76fc2840a25a6ea3b9637146806f1f44b090c175ffde2a7e5ab36c03"

    static let sharedContext = Result { try Context.setup(for: chainId) }

    enum ContextError: Error {
        case chainUnavailable
        case stakerUnavailable
    }

    final class Context {
        let storageFacade: StorageFacadeProtocol
        let chainRegistry: ChainRegistryProtocol
        let chain: ChainModel
        let apiFactory: SubtensorApiOperationFactoryProtocol
        let operationQueue: OperationQueue

        private var dynamicInfoList: [SubtensorStakingPallet.DynamicInfo]?
        private var alphaPrices: [SubtensorStakingPallet.SubnetPrice]?
        private var delegates: [SubtensorStakingPallet.DelegateInfo]?

        init(
            storageFacade: StorageFacadeProtocol,
            chainRegistry: ChainRegistryProtocol,
            chain: ChainModel,
            apiFactory: SubtensorApiOperationFactoryProtocol,
            operationQueue: OperationQueue
        ) {
            self.storageFacade = storageFacade
            self.chainRegistry = chainRegistry
            self.chain = chain
            self.apiFactory = apiFactory
            self.operationQueue = operationQueue
        }

        static func setup(for chainId: ChainModel.Id) throws -> Context {
            let storageFacade = SubstrateStorageTestFacade()
            let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
            let operationQueue = OperationQueue()

            let chainWrapper = chainRegistry.asyncWaitChainWrapper(for: chainId)

            let chain = try withExtendedLifetime(chainRegistry) {
                operationQueue.addOperations(chainWrapper.allOperations, waitUntilFinished: true)

                return try chainWrapper.targetOperation.extractNoCancellableResultData()
            }

            guard let chain else {
                throw ContextError.chainUnavailable
            }

            let connectionStore = ChainRegistryRuntimeConnectionStore(
                chainId: chainId,
                chainRegistry: chainRegistry
            )

            let apiFactory = SubtensorApiOperationFactory(
                runtimeConnectionStore: connectionStore,
                operationQueue: operationQueue
            )

            return Context(
                storageFacade: storageFacade,
                chainRegistry: chainRegistry,
                chain: chain,
                apiFactory: apiFactory,
                operationQueue: operationQueue
            )
        }

        func run<ResultType>(_ wrapper: CompoundOperationWrapper<ResultType>) throws -> ResultType {
            try withExtendedLifetime(self) {
                operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

                return try wrapper.targetOperation.extractNoCancellableResultData()
            }
        }

        func fetchDynamicInfoList() throws -> [SubtensorStakingPallet.DynamicInfo] {
            if let dynamicInfoList {
                return dynamicInfoList
            }

            let fetched = try run(apiFactory.createAllDynamicInfoWrapper()).compactMap { $0 }
            dynamicInfoList = fetched

            return fetched
        }

        func fetchAlphaPrices() throws -> [SubtensorStakingPallet.SubnetPrice] {
            if let alphaPrices {
                return alphaPrices
            }

            let fetched = try run(apiFactory.createAlphaPricesWrapper())
            alphaPrices = fetched

            return fetched
        }

        func fetchDelegates() throws -> [SubtensorStakingPallet.DelegateInfo] {
            if let delegates {
                return delegates
            }

            let fetched = try run(apiFactory.createDelegatesWrapper())
            delegates = fetched

            return fetched
        }

        func discoverStakedColdkey() throws -> AccountId {
            let staker = try fetchDelegates()
                .flatMap(\.nominators)
                .max { $0.totalStake < $1.totalStake }

            guard let staker, staker.totalStake > 0 else {
                throw ContextError.stakerUnavailable
            }

            return staker.nominator
        }
    }
}

private extension SubtensorStakingPallet.DelegateNomination {
    var totalStake: Balance {
        stakes.reduce(Balance(0)) { $0 + $1.stake }
    }
}
