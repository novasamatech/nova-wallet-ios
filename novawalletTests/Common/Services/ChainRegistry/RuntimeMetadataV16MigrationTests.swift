import Cuckoo
@testable import novawallet
import Operation_iOS
import SubstrateSdk
import XCTest

/// An install updated from a build that asked for metadata v15 has v15 cached for the current spec version.
/// It has to get v16 without waiting for a runtime upgrade and keep working from the cache until then.
final class RuntimeMetadataV16MigrationTests: XCTestCase {
    /// `RuntimeLocalVersion` of the builds that requested metadata v15 at most
    private static let previousBuildMigratorVersion: UInt32 = 2

    private let fixture = RuntimeMetadataFixture.polkadotAssetHub
    private let operationQueue = OperationQueue()

    private var storageFacade: SubstrateStorageTestFacade!
    private var eventCenter: EventCenter!
    private var observer: RuntimeEventsObserver!

    override func setUp() {
        super.setUp()

        storageFacade = SubstrateStorageTestFacade()
        eventCenter = EventCenter()
        observer = RuntimeEventsObserver()

        eventCenter.add(observer: observer, dispatchIn: nil)
    }

    func testCachedMetadataIsOlderThanCurrentMigrator() {
        XCTAssertLessThan(Self.previousBuildMigratorVersion, RuntimeLocalVersion.latest)
        XCTAssertEqual(RuntimeFetchOperationFactory.latestSupportedVersion, 16)
    }

    func testV15CachedByPreviousBuildIsReplacedWithV16() throws {
        // given

        try saveCachedV15()

        let connection = MetadataHashTestSetup.makeNode(for: fixture).makeConnection()
        let syncService = makeSyncService()
        let chain = fixture.makeChain()

        let syncCompleted = expectation(description: "metadata synced")
        observer.onMetadataSynced = { syncCompleted.fulfill() }

        // when: the node reports the spec version the cache already has

        syncService.register(chain: chain, with: connection)
        syncService.apply(version: runtimeVersion, for: chain.chainId)

        wait(for: [syncCompleted], timeout: 10)

        // then

        let item = try XCTUnwrap(fetchItem())

        XCTAssertEqual(item, try fixture.metadataItem(version: 16))
        XCTAssertEqual(try item.readMetadataVersion(), 16)
        XCTAssertEqual(item.localMigratorVersion, RuntimeLocalVersion.latest)
        XCTAssertEqual(connection.calls.last?.stateCall?.argument, "0x10000000")

        // when: the same spec version is reported again, as on every launch

        let callsCount = connection.calls.count

        let secondSyncCompleted = expectation(description: "second sync completed")
        observer.onMetadataSynced = { secondSyncCompleted.fulfill() }

        let secondSync = makeSyncService()
        secondSync.register(chain: chain, with: connection)
        secondSync.apply(version: runtimeVersion, for: chain.chainId)

        wait(for: [secondSyncCompleted], timeout: 10)

        // then: nothing is fetched

        XCTAssertEqual(connection.calls.count, callsCount)
        XCTAssertEqual(try fetchItem(), item)
    }

    func testChainOfferingV15AtMostIsRefetchedOnceAndKeepsV15() throws {
        try saveCachedV15()

        var node = MetadataHashTestSetup.makeNode(for: fixture)
        node.versions = [14, 15]

        let connection = node.makeConnection()
        let syncService = makeSyncService()
        let chain = fixture.makeChain()

        let syncCompleted = expectation(description: "metadata synced")
        observer.onMetadataSynced = { syncCompleted.fulfill() }

        syncService.register(chain: chain, with: connection)
        syncService.apply(version: runtimeVersion, for: chain.chainId)

        wait(for: [syncCompleted], timeout: 10)

        XCTAssertEqual(try fetchItem(), try fixture.metadataItem(version: 15))
        XCTAssertEqual(connection.calls.last?.stateCall?.argument, "0x0f000000")
    }

    func testAppDecodesWithCachedV15UntilV16Arrives() throws {
        // given: the runtime is built from the cache, as on a launch after the update

        try saveCachedV15()

        let chain = fixture.makeChain()
        let runtimeProvider = makeRuntimeProvider(for: chain)

        let cachedCoderReady = expectation(description: "coder from cache")
        observer.onCoderCreated = { cachedCoderReady.fulfill() }

        runtimeProvider.setup()

        wait(for: [cachedCoderReady], timeout: 10)

        // the node keeps the new metadata back until the test lets it go
        let metadataRequested = expectation(description: "v16 requested")
        let responseGate = DispatchSemaphore(value: 0)

        var node = MetadataHashTestSetup.makeNode(for: fixture)
        node.onCall = { call in
            if call.stateCall?.function == RuntimeFetchOperationFactory.metadataAtVersionCall {
                metadataRequested.fulfill()
                responseGate.wait()
            }
        }

        let syncService = makeSyncService()

        // when: the refetch is in flight

        syncService.register(chain: chain, with: node.makeConnection())
        syncService.apply(version: runtimeVersion, for: chain.chainId)

        wait(for: [metadataRequested], timeout: 10)

        // then: the cached runtime serves

        let cachedFactory = try fetchCoderFactory(from: runtimeProvider)

        XCTAssertTrue(cachedFactory.metadata is RuntimeMetadataV15)
        XCTAssertEqual(cachedFactory.specVersion, fixture.specVersion)
        XCTAssertNil(cachedFactory.metadata.getSupportedFormatVersions())

        let cachedTransfer = try encodeTransfer(with: cachedFactory)

        // when: v16 arrives

        let newCoderReady = expectation(description: "coder from v16")
        observer.onCoderCreated = { newCoderReady.fulfill() }

        responseGate.signal()

        wait(for: [newCoderReady], timeout: 10)

        // then: the runtime is rebuilt from it and encodes the same

        let newFactory = try fetchCoderFactory(from: runtimeProvider)

        XCTAssertTrue(newFactory.metadata is RuntimeMetadataV16)
        XCTAssertEqual(newFactory.metadata.getSupportedFormatVersions(), [4, 5])
        XCTAssertEqual(try encodeTransfer(with: newFactory), cachedTransfer)
    }

    func testCachedV15StaysWhenNodeIsUnreachable() throws {
        // given

        try saveCachedV15()

        let chain = fixture.makeChain()
        let runtimeProvider = makeRuntimeProvider(for: chain)

        let cachedCoderReady = expectation(description: "coder from cache")
        observer.onCoderCreated = { cachedCoderReady.fulfill() }

        runtimeProvider.setup()

        wait(for: [cachedCoderReady], timeout: 10)

        // neither the versioned nor the legacy call answers
        let legacyCallAttempted = expectation(description: "legacy call attempted")

        var node = RuntimeMetadataNodeScript(versions: nil, legacyMetadata: nil)
        node.onCall = { call in
            if call.method == RPCMethod.getRuntimeMetadata {
                legacyCallAttempted.fulfill()
            }
        }

        let syncService = makeSyncService()

        // when

        syncService.register(chain: chain, with: node.makeConnection())
        syncService.apply(version: runtimeVersion, for: chain.chainId)

        wait(for: [legacyCallAttempted], timeout: 10)

        // then: the cache is untouched, still marked for the refetch, and the runtime works

        let item = try XCTUnwrap(fetchItem())

        XCTAssertEqual(try item.readMetadataVersion(), 15)
        XCTAssertEqual(item.localMigratorVersion, Self.previousBuildMigratorVersion)
        XCTAssertTrue(syncService.isChainSyncing(chain.chainId))

        let factory = try fetchCoderFactory(from: runtimeProvider)

        XCTAssertTrue(factory.metadata is RuntimeMetadataV15)
        XCTAssertNoThrow(try encodeTransfer(with: factory))
    }
}

private final class RuntimeEventsObserver: EventVisitorProtocol {
    var onMetadataSynced: (() -> Void)?
    var onCoderCreated: (() -> Void)?

    func processRuntimeChainMetadataSyncCompleted(event _: RuntimeMetadataSyncCompleted) {
        onMetadataSynced?()
    }

    func processRuntimeCoderReady(event _: RuntimeCoderCreated) {
        onCoderCreated?()
    }
}

/// The failed sync is not repeated within a test
private struct NoRetryStrategy: ReconnectionStrategyProtocol {
    func reconnectAfter(attempt _: Int) -> TimeInterval? {
        nil
    }
}

private extension RuntimeMetadataV16MigrationTests {
    var runtimeVersion: RuntimeVersion {
        RuntimeVersion(specVersion: fixture.specVersion, transactionVersion: fixture.transactionVersion)
    }

    var repository: AnyDataProviderRepository<RuntimeMetadataItem> {
        RuntimeMetadataRepositoryFactory(storageFacade: storageFacade).createRepository()
    }

    func saveCachedV15() throws {
        let item = try fixture.metadataItem(version: 15, localMigratorVersion: Self.previousBuildMigratorVersion)
        let operation = repository.saveOperation({ [item] }, { [] })

        operationQueue.addOperations([operation], waitUntilFinished: true)

        try operation.extractNoCancellableResultData()
    }

    func fetchItem() throws -> RuntimeMetadataItem? {
        let operation = repository.fetchOperation(by: { self.fixture.chainId }, options: RepositoryFetchOptions())

        operationQueue.addOperations([operation], waitUntilFinished: true)

        return try operation.extractNoCancellableResultData()
    }

    func makeSyncService() -> RuntimeSyncService {
        RuntimeSyncService(
            repository: repository,
            runtimeFetchFactory: RuntimeFetchOperationFactory(operationQueue: operationQueue),
            runtimeLocalMigrator: RuntimeLocalMigrator.createLatest(),
            filesOperationFactory: MockRuntimeFilesOperationFactoryProtocol(),
            dataOperationFactory: MockDataOperationFactoryProtocol(),
            eventCenter: eventCenter,
            operationQueue: operationQueue,
            retryStrategy: NoRetryStrategy()
        )
    }

    func makeRuntimeProvider(for chain: ChainModel) -> RuntimeProvider {
        let snapshotFactory = RuntimeSnapshotFactory(
            chainId: chain.chainId,
            filesOperationFactory: MockRuntimeFilesOperationFactoryProtocol(),
            repository: repository,
            runtimeTypeRegistryFactory: RuntimeTypeRegistryFactory(logger: Logger.shared)
        )

        return RuntimeProvider(
            chainModel: chain,
            snapshotOperationFactory: snapshotFactory,
            eventCenter: eventCenter,
            operationQueue: operationQueue,
            logger: Logger.shared
        )
    }

    func fetchCoderFactory(from runtimeProvider: RuntimeProvider) throws -> RuntimeCoderFactoryProtocol {
        let operation = runtimeProvider.fetchCoderFactoryOperation()

        operationQueue.addOperations([operation], waitUntilFinished: true)

        return try operation.extractNoCancellableResultData()
    }

    func encodeTransfer(with codingFactory: RuntimeCoderFactoryProtocol) throws -> String {
        let call = try ExtrinsicGolden.transferCall().toScaleCompatibleJSON(
            with: codingFactory.createRuntimeJsonContext().toRawContext()
        )

        return try ExtrinsicGoldenRuntime(codingFactory: codingFactory).encodeCall(call)
    }
}
