import BigInt
@testable import novawallet
import Operation_iOS
import SubstrateSdk
import XCTest

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
            XCTAssertFalse(try XCTUnwrap(root).subnetName.isEmpty)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAlphaPricesArePositiveForSubnetsWithReservesAndRootPinnedToPriceScale() {
        do {
            let prices = try context.fetchAlphaPrices()

            Logger.shared.info("Prices: \(prices.count)")

            XCTAssertFalse(prices.isEmpty)

            let alphaReserves = try context.fetchDynamicInfoList().reduce(
                into: [UInt16: Balance]()
            ) { accum, dynamicInfo in
                accum[dynamicInfo.netuid] = dynamicInfo.alphaIn
            }

            for price in prices where alphaReserves[price.netuid, default: 0] > 0 {
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
            let dynamicNetuids = try Set(context.fetchDynamicInfoList().map(\.netuid))
            let priceNetuids = try Set(context.fetchAlphaPrices().map(\.netuid))

            XCTAssertEqual(dynamicNetuids, priceNetuids)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSingleAlphaPriceMatchesAllPricesAtPinnedBlock() {
        do {
            let blockHash = try context.run(context.apiFactory.createBestBlockHashWrapper())

            let prices = try context.run(context.apiFactory.createAlphaPricesWrapper(at: blockHash))

            let rootPrice = try context.run(
                context.apiFactory.createAlphaPriceWrapper(
                    for: SubtensorStakingPallet.rootNetuid,
                    blockHash: blockHash
                )
            )

            XCTAssertEqual(
                rootPrice,
                prices.first { $0.netuid == SubtensorStakingPallet.rootNetuid }?.price
            )

            let subnetPrice = try XCTUnwrap(
                prices.first { $0.netuid != SubtensorStakingPallet.rootNetuid && $0.price > 0 }
            )

            let singlePrice = try context.run(
                context.apiFactory.createAlphaPriceWrapper(
                    for: subnetPrice.netuid,
                    blockHash: blockHash
                )
            )

            XCTAssertEqual(singlePrice, subnetPrice.price)
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

    func testStakeInfoForDiscoveredStakerHasPositiveRootStake() {
        do {
            let coldkey = try context.discoverStakedColdkey()

            Logger.shared.info("Discovered staker: \(coldkey.toHex())")

            let stakeInfoList = try context.run(context.apiFactory.createStakeInfoWrapper(for: coldkey, blockHash: nil))

            XCTAssertFalse(stakeInfoList.isEmpty)

            let rootStake = stakeInfoList.first {
                $0.netuid == SubtensorStakingPallet.rootNetuid
            }?.stake

            XCTAssertGreaterThan(rootStake ?? 0, 0)

            let knownNetuids = try Set(context.fetchDynamicInfoList().map(\.netuid))

            for stakeInfo in stakeInfoList {
                XCTAssertEqual(stakeInfo.coldkey, coldkey)
                XCTAssertTrue(knownNetuids.contains(stakeInfo.netuid), "netuid \(stakeInfo.netuid)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testStakeAvailabilityCoversStakeInfoSubnetsAtPinnedBlock() {
        do {
            let coldkey = try context.discoverStakedColdkey()
            let blockHash = try context.run(context.apiFactory.createBestBlockHashWrapper())

            let stakeInfoList = try context.run(
                context.apiFactory.createStakeInfoWrapper(for: coldkey, blockHash: blockHash)
            )

            let availabilities = try context.run(
                context.apiFactory.createStakeAvailabilityWrapper(
                    for: [coldkey],
                    netuids: nil,
                    blockHash: blockHash
                )
            )

            let coldkeyAvailability = try XCTUnwrap(availabilities.first { $0.coldkey == coldkey })

            let stakeNetuids = Set(stakeInfoList.map(\.netuid))
            let availabilityNetuids = Set(coldkeyAvailability.subnets.map(\.netuid))

            XCTAssertTrue(stakeNetuids.isSubset(of: availabilityNetuids))

            for subnet in coldkeyAvailability.subnets {
                XCTAssertLessThanOrEqual(
                    subnet.availability.available,
                    subnet.availability.total,
                    "netuid \(subnet.netuid)"
                )
                XCTAssertTrue(
                    subnet.availability.total > 0 || subnet.availability.locked > 0,
                    "netuid \(subnet.netuid)"
                )
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testStakeAvailabilityWithExplicitNetuidsMatchesUnfilteredRootEntry() {
        do {
            let coldkey = try context.discoverStakedColdkey()
            let blockHash = try context.run(context.apiFactory.createBestBlockHashWrapper())

            let unfiltered = try context.run(
                context.apiFactory.createStakeAvailabilityWrapper(
                    for: [coldkey],
                    netuids: nil,
                    blockHash: blockHash
                )
            )

            let rootOnly = try context.run(
                context.apiFactory.createStakeAvailabilityWrapper(
                    for: [coldkey],
                    netuids: [SubtensorStakingPallet.rootNetuid],
                    blockHash: blockHash
                )
            )

            let unfilteredRootEntry = try XCTUnwrap(
                unfiltered
                    .first { $0.coldkey == coldkey }?
                    .subnets
                    .first { $0.netuid == SubtensorStakingPallet.rootNetuid }
            )

            let rootOnlyAvailability = try XCTUnwrap(rootOnly.first { $0.coldkey == coldkey })

            XCTAssertEqual(rootOnlyAvailability.subnets, [unfilteredRootEntry])
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private extension SubtensorStakingApiTests {
    static let chainId = KnowChainId.bittensor

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

            let fetched = try run(apiFactory.createDelegatesWrapper(at: nil))
            delegates = fetched

            return fetched
        }

        func discoverStakedColdkey() throws -> AccountId {
            let staker = try fetchDelegates()
                .flatMap(\.nominators)
                .max { $0.rootStake < $1.rootStake }

            guard let staker, staker.rootStake > 0 else {
                throw ContextError.stakerUnavailable
            }

            return staker.nominator
        }
    }
}

private extension SubtensorStakingPallet.DelegateNomination {
    var rootStake: Balance {
        stakes.first { $0.netuid == SubtensorStakingPallet.rootNetuid }?.stake ?? 0
    }
}
