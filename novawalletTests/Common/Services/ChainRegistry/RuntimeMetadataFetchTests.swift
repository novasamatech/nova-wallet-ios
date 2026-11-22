@testable import novawallet
import Operation_iOS
import SubstrateSdk
import XCTest

/// Which metadata the app asks a runtime for: the newest version it supports among the offered ones,
/// the legacy call when the runtime can't list versions.
final class RuntimeMetadataFetchTests: XCTestCase {
    private static let unstableVersion = UInt32.max

    private let operationQueue = OperationQueue()

    func testNewestSupportedVersionIsRequested() throws {
        let expectations: [([UInt32], UInt32)] = [
            ([14, 15, 16], 16),
            ([14, 15], 15),
            ([14], 14),
            ([16], 16),
            // polkadot-sdk releases before v16 was stabilised list it as u32::MAX: Mythos, peaq, Heima
            ([14, 15, Self.unstableVersion], 15),
            ([14, Self.unstableVersion], 14)
        ]

        for (versions, expectedVersion) in expectations {
            let script = RuntimeMetadataNodeScript(
                versions: versions,
                metadataByVersion: versions.reduce(into: [:]) { $0[$1] = Self.makeOpaqueMetadata(version: $1) }
            )

            let engine = script.makeEngine()

            let metadata = try fetch(from: engine)

            XCTAssertTrue(metadata.isOpaque)
            XCTAssertEqual(metadata.content, Self.makeOpaqueMetadata(version: expectedVersion), "\(versions)")
            XCTAssertEqual(try metadata.readMetadataVersion(), UInt8(truncatingIfNeeded: expectedVersion))

            XCTAssertEqual(engine.calls.compactMap(\.stateCall).map(\.function), [
                RuntimeFetchOperationFactory.availableVersionsCall,
                RuntimeFetchOperationFactory.metadataAtVersionCall
            ])

            XCTAssertEqual(
                engine.calls.last?.stateCall?.argument,
                try expectedVersion.scaleEncoded().toHex(includePrefix: true)
            )
        }
    }

    func testLegacyCallIsUsedWhenVersionsCantBeListed() throws {
        let legacyMetadata = Self.makeMetadata(version: 14)
        let engine = RuntimeMetadataNodeScript(versions: nil, legacyMetadata: legacyMetadata).makeEngine()

        let metadata = try fetch(from: engine)

        XCTAssertFalse(metadata.isOpaque)
        XCTAssertEqual(metadata.content, legacyMetadata)
        XCTAssertEqual(try metadata.readMetadataVersion(), 14)
        XCTAssertEqual(engine.calledMethods, [StateCallRpc.method, RPCMethod.getRuntimeMetadata])
    }

    func testLegacyCallIsUsedWhenNoOfferedVersionIsSupported() throws {
        let legacyMetadata = Self.makeMetadata(version: 14)

        let engine = RuntimeMetadataNodeScript(
            versions: [17, Self.unstableVersion],
            legacyMetadata: legacyMetadata
        ).makeEngine()

        let metadata = try fetch(from: engine)

        XCTAssertFalse(metadata.isOpaque)
        XCTAssertEqual(metadata.content, legacyMetadata)
        XCTAssertEqual(engine.calledMethods, [StateCallRpc.method, RPCMethod.getRuntimeMetadata])
    }

    func testLegacyCallIsUsedWhenVersionedMetadataFails() throws {
        let legacyMetadata = Self.makeMetadata(version: 14)

        // the version is listed but the call for its metadata fails
        let engine = RuntimeMetadataNodeScript(versions: [14, 15, 16], legacyMetadata: legacyMetadata).makeEngine()

        let metadata = try fetch(from: engine)

        XCTAssertFalse(metadata.isOpaque)
        XCTAssertEqual(metadata.content, legacyMetadata)
    }

    func testFailureWhenNeitherCallWorks() {
        let engine = RuntimeMetadataNodeScript(versions: nil, legacyMetadata: nil).makeEngine()

        XCTAssertThrowsError(try fetch(from: engine))
    }

    func testExactVersionIsRequestedAtBlock() throws {
        let script = RuntimeMetadataNodeScript(
            versions: [14, 15, 16],
            metadataByVersion: [15: Self.makeOpaqueMetadata(version: 15), 16: Self.makeOpaqueMetadata(version: 16)]
        )

        let engine = script.makeEngine()

        let metadata = try fetch(version: 15, blockHash: RuntimeMetadataNodeScript.blockHash, from: engine)

        XCTAssertEqual(metadata?.content, Self.makeOpaqueMetadata(version: 15))
        XCTAssertEqual(metadata?.isOpaque, true)

        let call = try XCTUnwrap(engine.calls.first?.stateCall)

        XCTAssertEqual(engine.calls.count, 1)
        XCTAssertEqual(call.function, RuntimeFetchOperationFactory.metadataAtVersionCall)
        XCTAssertEqual(call.argument, "0x0f000000")
        XCTAssertEqual(call.blockHash, RuntimeMetadataNodeScript.blockHash)
    }

    func testExactVersionTheRuntimeLacksIsNil() throws {
        let engine = RuntimeMetadataNodeScript(
            versions: [14, 16],
            metadataByVersion: [16: Self.makeOpaqueMetadata(version: 16)]
        ).makeEngine()

        XCTAssertNil(try fetch(version: 15, blockHash: nil, from: engine))
        XCTAssertNil(engine.calls.first?.stateCall?.blockHash)
    }

    func testExactVersionFailureIsReported() {
        let engine = RuntimeMetadataNodeScript(versions: [14, 15]).makeEngine()

        XCTAssertThrowsError(try fetch(version: 15, blockHash: nil, from: engine))
    }

    func testMetadataVersionIsReadFromHeader() throws {
        for version: UInt8 in [14, 15, 16] {
            let opaque = RawRuntimeMetadata(content: Self.makeOpaqueMetadata(version: UInt32(version)), isOpaque: true)
            let plain = RawRuntimeMetadata(content: Self.makeMetadata(version: UInt32(version)), isOpaque: false)

            XCTAssertEqual(try opaque.readMetadataVersion(), version)
            XCTAssertEqual(try plain.readMetadataVersion(), version)
        }

        XCTAssertNil(try RawRuntimeMetadata(content: Data([0]), isOpaque: true).readMetadataVersion())

        let truncated = Self.makeOpaqueMetadata(version: 15).dropLast(4)

        XCTAssertThrowsError(try RawRuntimeMetadata(content: Data(truncated), isOpaque: true).readMetadataVersion())
        XCTAssertThrowsError(try RawRuntimeMetadata(content: Data(), isOpaque: true).readMetadataVersion())
        XCTAssertThrowsError(try RawRuntimeMetadata(content: Data([0x6D, 0x65]), isOpaque: false).readMetadataVersion())
    }

    func testRealFixturesDeclareTheirVersion() throws {
        for fixture in RuntimeMetadataFixture.all {
            XCTAssertEqual(try fixture.rawMetadata(version: 15).readMetadataVersion(), 15)
            XCTAssertEqual(try fixture.rawMetadata(version: 16).readMetadataVersion(), 16)
        }
    }
}

extension RuntimeMetadataFetchTests {
    /// The header of prefixed metadata (magic number and version) followed by bytes that stand for the body
    static func makeMetadata(version: UInt32) -> Data {
        Data([0x6D, 0x65, 0x74, 0x61, UInt8(truncatingIfNeeded: version)]) + Data(repeating: 0xEE, count: 16)
    }

    /// `Some(OpaqueMetadata)`: the option flag, the compact length and the prefixed metadata
    static func makeOpaqueMetadata(version: UInt32) -> Data {
        let metadata = makeMetadata(version: version)

        // the compact length of a value shorter than 64 bytes is one byte
        return Data([1, UInt8(metadata.count << 2)]) + metadata
    }
}

private extension RuntimeMetadataFetchTests {
    func fetch(from engine: JSONRPCEngine) throws -> RawRuntimeMetadata {
        let wrapper = RuntimeFetchOperationFactory(operationQueue: operationQueue).createMetadataFetchWrapper(
            for: KnowChainId.polkadot,
            connection: engine
        )

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }

    func fetch(version: UInt32, blockHash: BlockHash?, from engine: JSONRPCEngine) throws -> RawRuntimeMetadata? {
        let wrapper = RuntimeFetchOperationFactory(operationQueue: operationQueue).createMetadataFetchWrapper(
            for: KnowChainId.polkadot,
            connection: engine,
            version: version,
            blockHash: blockHash
        )

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
