import Cuckoo
@testable import novawallet
import Operation_iOS
import SubstrateSdk
import XCTest

final class SubtensorSubnetParametersOperationFactoryTests: XCTestCase {
    func testSameBlockTypedReadsAndMetadataDefaultPreserveAllFacets() throws {
        let world = SubtensorStorageWorld()
        try world.set("0xc8000000", at: world.prefix(of: SystemPallet.blockNumberPath))
        try world.set("0x0c010001", at: world.key(SubtensorStakingPallet.validatorPermitPath, SubtensorStorageWorld.netuidKey(1), .identity))
        let result = try fetch(world: world)
        XCTAssertEqual(result.validators, 2)
        XCTAssertEqual(result.age, 1200)
        XCTAssertEqual(result.emission, 1)
        XCTAssertNotNil(result.subnet)
        XCTAssertEqual(result.blockHash, world.blockHash.toHex(includePrefix: true))
        XCTAssertEqual(world.recordedQueries.count, 3)
        XCTAssertTrue(world.recordedQueries.allSatisfy { $0.blockHash == world.blockHash })
        XCTAssertEqual(try world.requestedKeyCounts(for: SubtensorStakingPallet.subnetEmissionEnabledPath), [1])
    }

    func testStoredFalseEmissionAndMalformedIndependentFacet() throws {
        let world = SubtensorStorageWorld()
        try world.set("0x00", at: world.key(SubtensorStakingPallet.subnetEmissionEnabledPath, SubtensorStorageWorld.netuidKey(1), .identity))
        let result = try fetch(world: world, partial: true)
        XCTAssertEqual(result.emission, 0)
        XCTAssertNotNil(result.subnet)
        XCTAssertNil(result.age)
        try world.set("0xff", at: world.key(SubtensorStakingPallet.validatorPermitPath, SubtensorStorageWorld.netuidKey(1), .identity))
        let malformed = try fetch(world: world)
        XCTAssertNil(malformed.validators)
        XCTAssertNotNil(malformed.subnet)
    }

    func testFailedStorageAndTimelineKeepReservesAndPrice() throws {
        let result = try fetch(world: SubtensorStorageWorld(), failingStorage: true, failingTime: true)
        XCTAssertEqual(result.poolSplit, 0.2)
        XCTAssertEqual(result.alphaPrice, 500_000_000)
        XCTAssertNil(result.emission)
        XCTAssertNil(result.validators)
        XCTAssertNil(result.age)
    }

    func testCancelledSnapshotDropsLateCallback() throws {
        let world = SubtensorStorageWorld()
        let api = MockSubtensorApiOperationFactoryProtocol()
        let hash = world.blockHash.toHex(includePrefix: true)
        let queue = OperationQueue()
        queue.isSuspended = true
        stub(api) { stub in
            when(stub.createBestBlockHashWrapper()).thenReturn(.createWithResult(hash))
            when(stub.createAllDynamicInfoWrapper(at: any())).thenReturn(.createWithResult([SubtensorSubnetParametersTests.subnet()]))
            when(stub.createAlphaPricesWrapper(at: any())).thenReturn(.createWithResult([]))
        }
        let factory = try SubtensorSubnetParametersFactory(
            apiFactory: api,
            runtimeConnectionStore: world.makeConnectionStore(engine: world.makeEngine()),
            timeline: ParametersTimeline(fails: false),
            operationQueue: queue,
            logger: Logger.shared
        )
        let wrapper = factory.createWrapper(for: .init(netuid: 1, registeredAt: 100))
        let store = novawallet.CancellableCallStore()
        let late = expectation(description: "Cancelled snapshot must not reach presenter")
        late.isInverted = true
        novawallet.executeCancellable(wrapper: wrapper, inOperationQueue: queue, backingCallIn: store, runningCallbackIn: .main) { _ in late.fulfill() }
        store.cancel()
        queue.isSuspended = false
        wait(for: [late], timeout: 0.2)
        XCTAssertFalse(store.hasCall)
    }

    func testProductionAssemblyCompletesWithConfiguredBlockTime() throws {
        let chain = try productionChain(additional: ["defaultBlockTime": 12000])
        let result = try fetch(world: populatedWorld(), productionChain: chain)
        XCTAssertEqual(result.age, 1200)
        XCTAssertEqual(result.validators, 2)
        XCTAssertEqual(result.poolSplit, 0.2)
        XCTAssertEqual(result.emission, 1)
    }

    func testProductionAssemblyResolvesRuntimeExpectedBlockTimeWithoutEstimator() throws {
        let result = try fetch(world: populatedWorld(), productionChain: productionChain())
        XCTAssertGreaterThan(try XCTUnwrap(result.age), 0)
        XCTAssertEqual(result.validators, 2)
        XCTAssertEqual(result.poolSplit, 0.2)
    }

    func testProductionAssemblyMissingTimelineStillCompletesOtherFacets() throws {
        let chain = try productionChain(additional: ["timelineChain": "unavailable-timeline"])
        let result = try fetch(world: populatedWorld(), productionChain: chain)
        XCTAssertNil(result.age)
        XCTAssertEqual(result.validators, 2)
        XCTAssertEqual(result.poolSplit, 0.2)
        XCTAssertEqual(result.alphaPrice, 500_000_000)
        XCTAssertEqual(result.emission, 1)
    }

    func testProductionAssemblyKeepsFullRegistrationGuard() throws {
        let result = try fetch(world: populatedWorld(), productionChain: productionChain(), registeredAt: 99)
        XCTAssertNil(result.subnet)
        XCTAssertNil(result.age)
        XCTAssertNil(result.poolSplit)
        XCTAssertNil(result.validators)
        XCTAssertNil(result.alphaPrice)
    }

    private func populatedWorld() throws -> SubtensorStorageWorld {
        let world = SubtensorStorageWorld()
        try world.set("0xc8000000", at: world.prefix(of: SystemPallet.blockNumberPath))
        try world.set("0x0c010001", at: world.key(SubtensorStakingPallet.validatorPermitPath, SubtensorStorageWorld.netuidKey(1), .identity))
        return world
    }

    private func productionChain(additional: [String: Any] = [:]) throws -> ChainModel {
        let chain = SubtensorFlowChainWorld.chainAsset().chain
        let extras = try JSONDecoder().decode(JSON.self, from: JSONSerialization.data(withJSONObject: additional))
        return ChainModel(
            chainId: chain.chainId, parentId: chain.parentId, name: chain.name, assets: chain.assets,
            nodes: chain.nodes, nodeSwitchStrategy: chain.nodeSwitchStrategy, addressPrefix: chain.addressPrefix,
            legacyAddressPrefix: chain.legacyAddressPrefix, types: chain.types, icon: chain.icon,
            options: chain.options, externalApis: chain.externalApis, explorers: chain.explorers,
            order: chain.order, additional: extras, syncMode: chain.syncMode, source: chain.source,
            connectionMode: chain.connectionMode
        )
    }

    private func productionFactory(
        chain: ChainModel, world: SubtensorStorageWorld, api: SubtensorApiOperationFactoryProtocol, queue: OperationQueue
    ) throws -> SubnetParametersFactoryProtocol {
        let registry = MockChainRegistryProtocol()
        let state = MockSubtensorStakingSharedStateProtocol()
        let engine = world.makeEngine()
        let connection = MockConnection()
        let runtime = try world.makeConnectionStore(engine: engine).getRuntimeProvider()
        stub(connection.internalConnection) { stub in
            when(stub.callMethod(any(), params: any(StorageQuery.self), options: any(), completion: any())).then {
                (method: String, params: StorageQuery?, options: JSONRPCOptions, completion: ((Result<[StorageUpdate], Error>) -> Void)?) in
                try engine.callMethod(method, params: params, options: options, completion: completion)
            }
            when(stub.cancelForIdentifiers(any())).thenDoNothing()
        }
        stub(registry) { stub in
            when(stub.getChain(for: any())).then { $0 == chain.chainId ? chain : nil }
            when(stub.getConnection(for: equal(to: chain.chainId))).thenReturn(connection)
            when(stub.getRuntimeProvider(for: equal(to: chain.chainId))).thenReturn(runtime)
        }
        let chainAsset = ChainAsset(chain: chain, asset: SubtensorFlowChainWorld.chainAsset().asset)
        stub(state) { stub in
            when(stub.stakingOption.get).thenReturn(.init(chainAsset: chainAsset, type: .subtensor))
            when(stub.chainRegistry.get).thenReturn(registry)
            when(stub.apiOperationFactory.get).thenReturn(api)
            when(stub.logger.get).thenReturn(Logger.shared)
        }
        return SubtensorSubnetDetailsViewFactory.createParametersFactory(state: state, operationQueue: queue)
    }

    private func fetch(
        world: SubtensorStorageWorld, partial: Bool = false, failingStorage: Bool = false, failingTime: Bool = false,
        productionChain: ChainModel? = nil, registeredAt: UInt64 = 100
    ) throws -> SubtensorSubnetParameters {
        let api = MockSubtensorApiOperationFactoryProtocol()
        let hash = world.blockHash.toHex(includePrefix: true)
        let rows: [SubtensorStakingPallet.DynamicInfo?] = partial
            ? [SubtensorSubnetParametersTests.subnet(), nil] : [SubtensorSubnetParametersTests.subnet()]
        stub(api) { stub in
            when(stub.createBestBlockHashWrapper()).thenReturn(.createWithResult(hash))
            when(stub.createAllDynamicInfoWrapper(at: equal(to: hash))).thenReturn(.createWithResult(rows))
            when(stub.createAlphaPricesWrapper(at: equal(to: hash))).thenReturn(.createWithResult([.init(netuid: 1, price: 500_000_000)]))
        }
        let queue = OperationQueue()
        let factory: SubnetParametersFactoryProtocol
        if let productionChain {
            factory = try productionFactory(chain: productionChain, world: world, api: api, queue: queue)
        } else {
            factory = try SubtensorSubnetParametersFactory(
                apiFactory: api, runtimeConnectionStore: world.makeConnectionStore(engine: world.makeEngine(failingStorage: failingStorage)),
                timeline: ParametersTimeline(fails: failingTime), operationQueue: queue, logger: Logger.shared
            )
        }
        let wrapper = factory.createWrapper(for: .init(netuid: 1, registeredAt: registeredAt))
        let completed = expectation(description: "parameter snapshot")
        wrapper.targetOperation.completionBlock = { completed.fulfill() }
        queue.addOperations(wrapper.allOperations, waitUntilFinished: false)
        wait(for: [completed], timeout: 10)
        verify(api).createAllDynamicInfoWrapper(at: equal(to: hash))
        verify(api).createAlphaPricesWrapper(at: equal(to: hash))
        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}

private struct ParametersTimeline: ChainTimelineFacadeProtocol {
    let fails: Bool
    let timelineChainId = "chain"
    func createBlockTimeOperation() -> CompoundOperationWrapper<BlockTime> {
        fails ? .createWithError(CommonError.dataCorruption) : .createWithResult(12000)
    }
}
