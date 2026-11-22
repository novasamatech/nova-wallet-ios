import MetadataShortenerApi
@testable import novawallet
import Operation_iOS
import SubstrateSdk
import XCTest

/// Switching the app to metadata v16 must not change `CheckMetadataHash` or the proof a Ledger gets:
/// both stay generated from metadata v15 of the same runtime.
final class MetadataHashV16Tests: XCTestCase {
    private let fixture = RuntimeMetadataFixture.polkadotAssetHub
    private let operationQueue = OperationQueue()

    private var directory: URL!

    override func setUp() {
        super.setUp()

        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)

        super.tearDown()
    }

    func testHashWithV16RuntimeIsTheHashOfV15Runtime() throws {
        // given: the app as it was, metadata v15 stored and decoded with

        let v15Setup = try makeSetup(storedVersion: 15)
        let v15Node = MetadataHashTestSetup.makeNode(for: fixture).makeEngine()

        let hashBefore = try XCTUnwrap(fetchHash(setup: v15Setup, runtimeVersion: 15, engine: v15Node))

        XCTAssertEqual(hashBefore, try generateHashDirectly())
        XCTAssertEqual(v15Node.calledMethods, [RPCMethod.getRuntimeVersion])

        // when: metadata v16 is stored and decoded with

        let v16Setup = try makeSetup(storedVersion: 16)
        let v16Node = MetadataHashTestSetup.makeNode(for: fixture).makeEngine()

        let hashAfter = try XCTUnwrap(fetchHash(setup: v16Setup, runtimeVersion: 16, engine: v16Node))

        // then

        XCTAssertEqual(hashAfter, hashBefore)
        XCTAssertEqual(hashAfter.count, 32)
        XCTAssertTrue(v16Node.calls.contains { $0.stateCall?.function == RuntimeFetchOperationFactory.metadataAtVersionCall })
    }

    func testHashNeedsNoMetadataFromNetworkOnceV15IsKept() throws {
        let setup = try makeSetup(storedVersion: 16)

        let firstHash = try fetchHash(
            setup: setup,
            runtimeVersion: 16,
            engine: MetadataHashTestSetup.makeNode(for: fixture).makeEngine()
        )

        // a new factory, as a new screen makes one: the in-memory cache of the previous one is gone
        let engine = MetadataHashTestSetup.makeNode(for: fixture).makeEngine()

        let nextHash = try fetchHash(setup: setup, runtimeVersion: 16, engine: engine)

        XCTAssertEqual(nextHash, firstHash)

        // the runtime version was asked before the change too
        XCTAssertEqual(engine.calledMethods, [RPCMethod.getRuntimeVersion])
    }

    func testNoHashWhenRuntimeHasNoV15() throws {
        let setup = try makeSetup(storedVersion: 16)

        var node = MetadataHashTestSetup.makeNode(for: fixture)
        node.versions = [14, 16]

        XCTAssertNil(try fetchHash(setup: setup, runtimeVersion: 16, engine: node.makeEngine()))
    }

    func testHashFailsWhenV15CantBeFetched() throws {
        let setup = try makeSetup(storedVersion: 16)

        var node = MetadataHashTestSetup.makeNode(for: fixture)
        node.metadataByVersion = [:]

        XCTAssertThrowsError(try fetchHash(setup: setup, runtimeVersion: 16, engine: node.makeEngine()))
    }

    func testProofWithV16RuntimeIsTheProofOfV15Runtime() throws {
        let v15Setup = try makeSetup(storedVersion: 15)

        let proofBefore = try fetchProof(
            setup: v15Setup,
            runtimeVersion: 15,
            engine: MetadataHashTestSetup.makeNode(for: fixture).makeEngine()
        )

        let v16Setup = try makeSetup(storedVersion: 16)

        let proofAfter = try fetchProof(
            setup: v16Setup,
            runtimeVersion: 16,
            engine: MetadataHashTestSetup.makeNode(for: fixture).makeEngine()
        )

        XCTAssertEqual(proofAfter, proofBefore)
        XCTAssertFalse(proofAfter.isEmpty)

        // every next proof takes v15 from the device
        let engine = MetadataHashTestSetup.makeNode(for: fixture).makeEngine()

        XCTAssertEqual(try fetchProof(setup: v16Setup, runtimeVersion: 16, engine: engine), proofBefore)
        XCTAssertEqual(engine.calledMethods, [RPCMethod.getRuntimeVersion])
    }

    func testProofFailsWhenRuntimeHasNoV15() throws {
        let setup = try makeSetup(storedVersion: 16)

        var node = MetadataHashTestSetup.makeNode(for: fixture)
        node.versions = [14, 16]

        XCTAssertThrowsError(try fetchProof(setup: setup, runtimeVersion: 16, engine: node.makeEngine())) { error in
            guard case CommonMetadataShortenerError.metadataMissing = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }
}

private extension MetadataHashV16Tests {
    /// A store with the runtime metadata of the given version and its own empty directory for runtime files
    func makeSetup(storedVersion: UInt32) throws -> MetadataHashTestSetup {
        let setup = MetadataHashTestSetup(
            storageFacade: SubstrateStorageTestFacade(),
            directory: directory.appendingPathComponent("v\(storedVersion)"),
            operationQueue: operationQueue
        )

        try setup.save(fixture.metadataItem(version: storedVersion))

        return setup
    }

    func fetchHash(setup: MetadataHashTestSetup, runtimeVersion: UInt32, engine: JSONRPCEngine) throws -> Data? {
        let factory = MetadataHashOperationFactory(sourceProvider: setup.makeProvider(), operationQueue: operationQueue)

        let wrapper = factory.createCheckMetadataHashWrapper(
            for: fixture.makeChain(),
            connection: engine,
            runtimeProvider: RuntimeCodingServiceStub(factory: try fixture.runtime(version: runtimeVersion).codingFactory)
        )

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }

    func fetchProof(setup: MetadataHashTestSetup, runtimeVersion: UInt32, engine: JSONRPCEngine) throws -> Data {
        let runtime = try fixture.runtime(version: runtimeVersion)

        let extensions = ExtrinsicSignedExtensionFacade().createFactory(for: fixture.chainId).createExtensions()

        let builder = try extensions.reduce(try runtime.makeBuilder()) { $0.adding(transactionExtension: $1) }
            .with(metadataHash: ExtrinsicGolden.metadataHash)
            .adding(call: ExtrinsicGolden.transferCall())

        let wrapper = ExtrinsicProofOperationFactory(sourceProvider: setup.makeProvider()).createExtrinsicProofWrapper(
            for: fixture.makeChain(),
            connection: engine,
            signatureParamsClosure: { try runtime.signatureParams(of: builder) }
        )

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }

    /// The hash the way it was generated before the provider existed: straight from the stored v15 bytes
    func generateHashDirectly() throws -> Data {
        let params = MetadataHashParams(
            metadata: try fixture.rawMetadata(version: 15).content,
            specVersion: fixture.specVersion,
            specName: fixture.specName,
            decimals: 10,
            base58Prefix: 0,
            tokenSymbol: "DOT"
        )

        return try MetadataShortenerApi().generateMetadataHash(for: params)
    }
}
