@testable import novawallet
import Operation_iOS
import SubstrateSdk
import XCTest

/// What the app encodes and decodes with the runtime built from metadata v16 has to be byte for byte what it
/// encoded and decoded with v15 of the same runtime: extrinsics, signature payloads, storage keys and values,
/// constants and events. Both runtimes come from `RuntimeTypeRegistryFactory`, as in the app.
final class RuntimeMetadataV16CodingTests: XCTestCase {
    typealias BuilderClosure = (ExtrinsicBuilderProtocol, ExtrinsicGoldenRuntime) throws -> ExtrinsicBuilderProtocol

    private let operationQueue = OperationQueue()

    func testExtrinsicAndSignaturePayloadAreTheSame() throws {
        let cases: [(String, BuilderClosure)] = [
            ("transfer", { builder, _ in
                try builder.with(metadataHash: ExtrinsicGolden.metadataHash).adding(call: ExtrinsicGolden.transferCall())
            }),
            ("transfer without metadata hash", { builder, _ in
                try builder.adding(call: ExtrinsicGolden.transferCall())
            }),
            ("payload long enough to be hashed", { builder, _ in
                try builder.with(metadataHash: ExtrinsicGolden.metadataHash).adding(call: ExtrinsicGolden.remarkCall(size: 300))
            }),
            ("batch", { builder, runtime in
                try builder
                    .with(metadataHash: ExtrinsicGolden.metadataHash)
                    .adding(call: ExtrinsicGolden.transferCall())
                    .adding(call: ExtrinsicGolden.remarkCall(size: 8))
                    .with(batchType: .atomic)
                    .batchingCalls(with: runtime.metadata)
            }),
            ("Polkadot Vault payload", { builder, _ in
                try builder
                    .with(metadataHash: ExtrinsicGolden.metadataHash)
                    .with(signaturePayloadFormat: .paritySigner)
                    .adding(call: ExtrinsicGolden.transferCall())
            })
        ]

        for fixture in RuntimeMetadataFixture.all {
            for (name, closure) in cases {
                let v15 = try sign(closure, fixture: fixture, version: 15)
                let v16 = try sign(closure, fixture: fixture, version: 16)

                XCTAssertFalse(v16.signed.extrinsic.isEmpty)
                XCTAssertEqual(v16.signed.extrinsic, v15.signed.extrinsic, "\(fixture.name): \(name)")
                XCTAssertEqual(v16.signed.signedPayload, v15.signed.signedPayload, "\(fixture.name): \(name)")
                XCTAssertEqual(v16.params.encodedCall, v15.params.encodedCall)
                XCTAssertEqual(v16.params.includedInExtrinsicExtra, v15.params.includedInExtrinsicExtra)
                XCTAssertEqual(v16.params.includedInSignatureExtra, v15.params.includedInSignatureExtra)
            }
        }
    }

    func testExtrinsicBuiltWithOneVersionIsDecodedWithTheOther() throws {
        for fixture in RuntimeMetadataFixture.all {
            let v15Runtime = try fixture.runtime(version: 15)
            let v16Runtime = try fixture.runtime(version: 16)

            let extrinsic = try sign(
                { builder, _ in
                    try builder.with(metadataHash: ExtrinsicGolden.metadataHash).adding(call: ExtrinsicGolden.transferCall())
                },
                fixture: fixture,
                version: 15
            ).signed.extrinsic

            let v15Decoded = try v15Runtime.decodeExtrinsic(extrinsic)
            let v16Decoded = try v16Runtime.decodeExtrinsic(extrinsic)

            XCTAssertEqual(try ExtrinsicGolden.json(v16Decoded), try ExtrinsicGolden.json(v15Decoded), fixture.name)
            XCTAssertNotNil(v16Decoded.getSignedExtrinsic())
        }
    }

    func testStorageKeysAreTheSame() throws {
        for fixture in RuntimeMetadataFixture.all {
            let v15Key = try encodeAccountKey(with: fixture.runtime(version: 15))
            let v16Key = try encodeAccountKey(with: fixture.runtime(version: 16))

            XCTAssertEqual(v16Key, v15Key, fixture.name)

            // twox128("System") + twox128("Account") + blake2_128(account id) + account id
            XCTAssertEqual(v16Key.count, 16 + 16 + 16 + 32)
            XCTAssertEqual(
                v16Key.prefix(32).toHex(),
                "26aa394eea5630e07c48ae0c9558cef7b99d880ec681799c0cf30e8886371da9"
            )
            XCTAssertEqual(v16Key.suffix(32), ExtrinsicGolden.senderId)
        }

        let assetHub = RuntimeMetadataFixture.polkadotAssetHub

        XCTAssertEqual(
            try encodeAssetAccountKey(with: assetHub.runtime(version: 16)),
            try encodeAssetAccountKey(with: assetHub.runtime(version: 15))
        )
    }

    func testStorageValuesAreDecodedTheSameWay() throws {
        for fixture in RuntimeMetadataFixture.all {
            let entries = try decodeItems(of: fixture) { metadata in
                metadata.postV14Pallets.flatMap { pallet in
                    (pallet.storage?.entries ?? []).compactMap { entry -> Item? in
                        // the default of an entry that has one is a value of its type
                        guard entry.modifier == .defaultModifier else {
                            return nil
                        }

                        let type: SiLookupId

                        switch entry.type {
                        case let .plain(valueType):
                            type = valueType
                        case let .map(map):
                            type = map.value
                        }

                        return Item(name: "\(pallet.name).\(entry.name)", type: type, value: entry.defaultValue)
                    }
                }
            }

            XCTAssertGreaterThan(entries, 150, fixture.name)
        }
    }

    func testAccountInfoIsDecodedTheSameWay() throws {
        // nonce, consumers, providers, sufficients and the four balances of AccountData
        let counters: [UInt32] = [7, 1, 2, 0]
        let balances: [UInt8] = [0x10, 0x20, 0x30, 0x40]

        let accountInfo = counters.reduce(Data()) { $0 + DAppTxPayloadFixture.littleEndian($1) } +
            balances.reduce(Data()) { $0 + Data([$1]) + Data(repeating: 0, count: 15) }

        for fixture in RuntimeMetadataFixture.all {
            let v15Info = try decodeStorageValue(accountInfo, path: SystemPallet.accountPath, fixture: fixture, version: 15)
            let v16Info = try decodeStorageValue(accountInfo, path: SystemPallet.accountPath, fixture: fixture, version: 16)

            XCTAssertEqual(v16Info, v15Info, fixture.name)
            XCTAssertEqual(v16Info.dictValue?["nonce"]?.stringValue, "7")
            XCTAssertEqual(v16Info.dictValue?["data"]?.dictValue?["free"]?.stringValue, "16")
        }
    }

    func testConstantsAreDecodedTheSameWay() throws {
        for fixture in RuntimeMetadataFixture.all {
            let constants = try decodeItems(of: fixture) { metadata in
                metadata.postV14Pallets.flatMap { pallet in
                    pallet.constants.map { Item(name: "\(pallet.name).\($0.name)", type: $0.type, value: $0.value) }
                }
            }

            XCTAssertGreaterThan(constants, 100, fixture.name)

            let v15Factory = try fixture.runtime(version: 15).codingFactory
            let v16Factory = try fixture.runtime(version: 16).codingFactory

            let blockHashCount = ConstantCodingPath(moduleName: "System", constantName: "BlockHashCount")

            for path in [ConstantCodingPath.existentialDeposit, blockHashCount] {
                let v15Constant = try XCTUnwrap(v15Factory.getConstant(for: path))
                let v16Constant = try XCTUnwrap(v16Factory.getConstant(for: path))

                XCTAssertEqual(v16Constant.value, v15Constant.value)
                XCTAssertEqual(
                    try v16Factory.createDecoder(from: v16Constant.value).read(type: v16Constant.type),
                    try v15Factory.createDecoder(from: v15Constant.value).read(type: v15Constant.type)
                )
            }
        }
    }

    func testEventsAreDecodedTheSameWay() throws {
        for fixture in RuntimeMetadataFixture.all {
            let metadata = try fixture.runtime(version: 16).metadata
            let balancesIndex = try XCTUnwrap(metadata.getModuleIndex("Balances"))

            let transferIndex = try XCTUnwrap(
                (UInt8.min ... UInt8.max).first {
                    metadata.getEventForModuleIndex(balancesIndex, eventIndex: UInt32($0))?.name == "Transfer"
                }
            )

            // Vec<EventRecord> with one record: phase ApplyExtrinsic(2), Balances.Transfer, no topics
            let records = Data([0x04, 0x00]) + DAppTxPayloadFixture.littleEndian(2) +
                Data([balancesIndex, transferIndex]) + ExtrinsicGolden.senderId + ExtrinsicGolden.receiverId +
                Data([0xE8, 0x03]) + Data(repeating: 0, count: 14) + Data([0x00])

            let v15Events = try decodeStorageValue(records, path: SystemPallet.eventsPath, fixture: fixture, version: 15)
            let v16Events = try decodeStorageValue(records, path: SystemPallet.eventsPath, fixture: fixture, version: 16)

            XCTAssertEqual(v16Events, v15Events, fixture.name)
            XCTAssertEqual(v16Events.arrayValue?.count, 1)
        }
    }
}

private extension RuntimeMetadataV16CodingTests {
    struct Item {
        let name: String
        let type: SiLookupId
        let value: Data
    }

    struct Signed {
        let signed: ExtrinsicGoldenRuntime.Signed
        let params: ExtrinsicSignatureParams
    }

    func sign(_ closure: BuilderClosure, fixture: RuntimeMetadataFixture, version: UInt32) throws -> Signed {
        let runtime = try fixture.runtime(version: version)

        // the extensions every native transaction of the chain gets from the app
        let extensions = ExtrinsicSignedExtensionFacade().createFactory(for: fixture.chainId).createExtensions()

        let builder = try closure(
            extensions.reduce(try runtime.makeBuilder()) { $0.adding(transactionExtension: $1) },
            runtime
        )

        return Signed(signed: try runtime.sign(builder), params: try runtime.signatureParams(of: builder))
    }

    /// Decodes the same bytes with the type each metadata version names for them and compares the results.
    /// Returns how many values were decoded.
    func decodeItems(
        of fixture: RuntimeMetadataFixture,
        itemsClosure: (PostV14RuntimeMetadataProtocol) -> [Item]
    ) throws -> Int {
        let v15Factory = try fixture.runtime(version: 15).codingFactory
        let v16Factory = try fixture.runtime(version: 16).codingFactory

        let v15Items = itemsClosure(try fixture.postV14Metadata(version: 15))
        let v16Items = itemsClosure(try fixture.postV14Metadata(version: 16))

        XCTAssertEqual(v16Items.map(\.name), v15Items.map(\.name), fixture.name)

        var decodedCount = 0

        for (v15Item, v16Item) in zip(v15Items, v16Items) {
            XCTAssertEqual(v16Item.value, v15Item.value, v15Item.name)

            // a value the dynamic decoder can't read is not readable with either version
            let v15Value = try? v15Factory.createDecoder(from: v15Item.value).read(type: String(v15Item.type))
            let v16Value = try? v16Factory.createDecoder(from: v16Item.value).read(type: String(v16Item.type))

            XCTAssertEqual(v16Value, v15Value, "\(fixture.name): \(v15Item.name)")

            decodedCount += v16Value != nil ? 1 : 0
        }

        return decodedCount
    }

    func decodeStorageValue(
        _ value: Data,
        path: StorageCodingPath,
        fixture: RuntimeMetadataFixture,
        version: UInt32
    ) throws -> JSON {
        let codingFactory = try fixture.runtime(version: version).codingFactory

        let entry = try XCTUnwrap(
            codingFactory.metadata.getStorageMetadata(in: path.moduleName, storageName: path.itemName)
        )

        let decoder = try codingFactory.createDecoder(from: value)
        let json = try decoder.read(type: entry.type.typeName)

        XCTAssertEqual(decoder.remained, 0)

        return json
    }

    func encodeAccountKey(with runtime: ExtrinsicGoldenRuntime) throws -> Data {
        let operation = MapKeyEncodingOperation<BytesCodable>(
            path: SystemPallet.accountPath,
            storageKeyFactory: StorageKeyFactory(),
            keyParams: [BytesCodable(wrappedValue: ExtrinsicGolden.senderId)]
        )

        operation.codingFactory = runtime.codingFactory

        operationQueue.addOperations([operation], waitUntilFinished: true)

        return try XCTUnwrap(operation.extractNoCancellableResultData().first)
    }

    func encodeAssetAccountKey(with runtime: ExtrinsicGoldenRuntime) throws -> Data {
        let operation = DoubleMapKeyEncodingOperation<String, BytesCodable>(
            path: StorageCodingPath(moduleName: "Assets", itemName: "Account"),
            storageKeyFactory: StorageKeyFactory(),
            keyParams1: ["1984"],
            keyParams2: [BytesCodable(wrappedValue: ExtrinsicGolden.senderId)]
        )

        operation.codingFactory = runtime.codingFactory

        operationQueue.addOperations([operation], waitUntilFinished: true)

        return try XCTUnwrap(operation.extractNoCancellableResultData().first)
    }
}
