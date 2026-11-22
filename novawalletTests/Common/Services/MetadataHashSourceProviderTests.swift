@testable import novawallet
import Operation_iOS
import SubstrateSdk
import XCTest

/// The metadata hash and the proof for a hardware wallet are defined over metadata v15. The provider has to
/// hand out v15 of the spec version the app works with, without a network call once it has been kept.
final class MetadataHashSourceProviderTests: XCTestCase {
    private let fixture = RuntimeMetadataFixture.polkadotAssetHub
    private let operationQueue = OperationQueue()

    private var storageFacade: SubstrateStorageTestFacade!
    private var directory: URL!

    override func setUp() {
        super.setUp()

        storageFacade = SubstrateStorageTestFacade()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)

        super.tearDown()
    }

    func testStoredV15MetadataIsTheSource() throws {
        let item = try fixture.metadataItem(version: 15)
        try save(item)

        let engine = MetadataHashTestSetup.makeUnreachableNode()

        let source = try fetchSource(from: engine)

        XCTAssertEqual(source, MetadataHashSource(specVersion: fixture.specVersion, metadata: item.metadata))
        XCTAssertEqual(engine.calls, [])
        XCTAssertNil(try readStoredSource())
    }

    func testMetadataOlderThanV15IsHandedOverAsBefore() throws {
        // what the legacy call returns: not opaque and of version 14
        let item = RuntimeMetadataItem(
            chain: fixture.chainId,
            version: 9,
            txVersion: 1,
            localMigratorVersion: RuntimeLocalVersion.latest,
            opaque: false,
            metadata: RuntimeMetadataFetchTests.makeMetadata(version: 14)
        )

        try save(item)

        let engine = MetadataHashTestSetup.makeUnreachableNode()

        XCTAssertEqual(try fetchSource(from: engine), MetadataHashSource(specVersion: 9, metadata: item.metadata))
        XCTAssertEqual(engine.calls, [])
    }

    func testMissingRuntimeMetadataIsAnError() {
        XCTAssertThrowsError(try fetchSource(from: MetadataHashTestSetup.makeUnreachableNode())) { error in
            guard case CommonMetadataShortenerError.metadataMissing = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testV15IsFetchedOnceWhenStoredMetadataIsV16() throws {
        try save(fixture.metadataItem(version: 16))

        let v15Metadata = try fixture.rawMetadata(version: 15).content
        let engine = MetadataHashTestSetup.makeNode(for: fixture).makeEngine()

        // when: the first need

        let source = try fetchSource(from: engine)

        // then: v15 and the runtime version are read at one block and v15 is kept

        XCTAssertEqual(source, MetadataHashSource(specVersion: fixture.specVersion, metadata: v15Metadata))

        let blockHash = RuntimeMetadataNodeScript.blockHash

        XCTAssertEqual(engine.calls.first, .init(method: RPCMethod.getBlockHash, params: []))
        XCTAssertEqual(engine.calls.count, 3)
        XCTAssertTrue(engine.calls.contains(.init(method: RPCMethod.getRuntimeVersion, params: [blockHash])))
        XCTAssertTrue(
            engine.calls.contains(
                .init(
                    method: StateCallRpc.method,
                    params: [RuntimeFetchOperationFactory.metadataAtVersionCall, "0x0f000000", blockHash]
                )
            )
        )

        XCTAssertEqual(try readStoredSource(), source)

        // when: every next need

        let unreachableNode = MetadataHashTestSetup.makeUnreachableNode()

        XCTAssertEqual(try fetchSource(from: unreachableNode), source)
        XCTAssertEqual(unreachableNode.calls, [])
    }

    func testSourceOfAnotherSpecVersionIsReplaced() throws {
        try save(fixture.metadataItem(version: 16))

        let v15Metadata = try fixture.rawMetadata(version: 15).content

        try store(MetadataHashSource(specVersion: fixture.specVersion - 1, metadata: v15Metadata))

        let engine = MetadataHashTestSetup.makeNode(for: fixture).makeEngine()

        let source = try fetchSource(from: engine)

        XCTAssertEqual(source?.specVersion, fixture.specVersion)
        XCTAssertEqual(engine.calls.count, 3)
        XCTAssertEqual(try readStoredSource(), source)
    }

    func testUnreadableStoredSourceIsFetchedAgain() throws {
        try save(fixture.metadataItem(version: 16))

        let v15Metadata = try fixture.rawMetadata(version: 15).content
        let validSource = MetadataHashSource(specVersion: fixture.specVersion, metadata: v15Metadata)

        let brokenFiles: [Data] = [
            Data(),
            Data([0x01, 0x02]),
            // cut in the middle: the length the opaque value declares doesn't fit
            try validSource.scaleEncoded().dropLast(1000),
            // metadata of the version the app decodes with is not what the hash is defined over
            try MetadataHashSource(
                specVersion: fixture.specVersion,
                metadata: fixture.rawMetadata(version: 16).content
            ).scaleEncoded()
        ]

        for brokenFile in brokenFiles {
            try write(Data(brokenFile))

            let engine = MetadataHashTestSetup.makeNode(for: fixture).makeEngine()

            XCTAssertEqual(try fetchSource(from: engine), validSource)
            XCTAssertEqual(engine.calls.count, 3)
            XCTAssertEqual(try readStoredSource(), validSource)
        }
    }

    func testNothingIsKeptWhenRuntimeIsOfAnotherSpecVersion() throws {
        try save(fixture.metadataItem(version: 16))

        var node = MetadataHashTestSetup.makeNode(for: fixture)
        node.runtimeVersion = RuntimeVersionFull(
            specVersion: fixture.specVersion + 1,
            transactionVersion: fixture.transactionVersion,
            specName: fixture.specName
        )

        XCTAssertThrowsError(try fetchSource(from: node.makeEngine())) { error in
            guard
                case let CommonMetadataShortenerError.invalidMetadata(localVersion, remoteVersion) = error else {
                return XCTFail("Unexpected error: \(error)")
            }

            XCTAssertEqual(localVersion, fixture.specVersion)
            XCTAssertEqual(remoteVersion, fixture.specVersion + 1)
        }

        XCTAssertNil(try readStoredSource())
    }

    func testRuntimeWithoutV15HasNoSource() throws {
        try save(fixture.metadataItem(version: 16))

        var node = MetadataHashTestSetup.makeNode(for: fixture)
        node.versions = [14, 16]

        XCTAssertNil(try fetchSource(from: node.makeEngine()))
        XCTAssertNil(try readStoredSource())
    }

    func testMetadataOfUnexpectedVersionIsNotKept() throws {
        try save(fixture.metadataItem(version: 16))

        var node = MetadataHashTestSetup.makeNode(for: fixture)
        node.metadataByVersion[15] = try fixture.rawMetadata(version: 16).content

        XCTAssertThrowsError(try fetchSource(from: node.makeEngine()))
        XCTAssertNil(try readStoredSource())
    }

    func testNodeFailureIsReported() throws {
        try save(fixture.metadataItem(version: 16))

        var node = MetadataHashTestSetup.makeNode(for: fixture)
        node.metadataByVersion = [:]

        XCTAssertThrowsError(try fetchSource(from: node.makeEngine()))
        XCTAssertNil(try readStoredSource())
    }

    func testStoredSourceKeepsSpecVersionAndBytes() throws {
        let source = MetadataHashSource(specVersion: 2_005_003, metadata: Data([0x01, 0x02, 0x03]))

        let encoded = try source.scaleEncoded()

        // the spec version as u32 followed by the metadata as it is
        XCTAssertEqual(encoded.toHex(), "0b981e00010203")
        XCTAssertEqual(try MetadataHashSource(scaleDecoder: ScaleDecoder(data: encoded)), source)
    }
}

private extension MetadataHashSourceProviderTests {
    var setup: MetadataHashTestSetup {
        MetadataHashTestSetup(storageFacade: storageFacade, directory: directory, operationQueue: operationQueue)
    }

    func save(_ item: RuntimeMetadataItem) throws {
        try setup.save(item)
    }

    func store(_ source: MetadataHashSource) throws {
        try write(source.scaleEncoded())
    }

    func write(_ data: Data) throws {
        try setup.writeStoredSource(data, chainId: fixture.chainId)
    }

    func readStoredSource() throws -> MetadataHashSource? {
        try setup.readStoredSource(chainId: fixture.chainId)
    }

    func fetchSource(from engine: JSONRPCEngine) throws -> MetadataHashSource? {
        let wrapper = setup.makeProvider().createFetchWrapper(for: fixture.chainId, connection: engine)

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
