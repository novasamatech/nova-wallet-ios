@testable import novawallet
import SubstrateSdk
import XCTest

/// Pins what the app reads from decoded runtime metadata (v14 Westend, v15 Bittensor fixtures) and from the
/// type registry built on top of it. Golden values were recorded on substrate-sdk-ios 4.5.2.
final class RuntimeMetadataCharacterizationTests: XCTestCase {
    // MARK: Container

    func testContainerVersions() throws {
        let westend = try RuntimeHelper.createRuntimeMetadata("westend-metadata")
        let bittensor = try RuntimeHelper.createRuntimeMetadata("bittensor-v15-metadata")

        XCTAssertEqual(westend.runtimeMetadataVersion, 14)
        XCTAssertEqual(bittensor.runtimeMetadataVersion, 15)
        XCTAssertEqual(westend.metaReserved, 0x6174_656D)
        XCTAssertEqual(bittensor.metaReserved, 0x6174_656D)

        guard case .v14 = westend.runtimeMetadata, case .v15 = bittensor.runtimeMetadata else {
            return XCTFail("Unexpected metadata containers")
        }
    }

    func testRuntimeVersionSupportFlags() throws {
        let westend = try ExtrinsicGoldenRuntime.westend().codingFactory
        let bittensor = try ExtrinsicGoldenRuntime.bittensor().codingFactory
        let assetHub = try ExtrinsicGoldenRuntime.polkadotAssetHub().codingFactory

        XCTAssertFalse(westend.atLeastV15Runtime())
        XCTAssertFalse(westend.supportsMetadataHash())
        XCTAssertTrue(bittensor.atLeastV15Runtime())
        XCTAssertTrue(bittensor.supportsMetadataHash())
        // v14 metadata with the CheckMetadataHash extension still does not qualify
        XCTAssertFalse(assetHub.atLeastV15Runtime())
        XCTAssertFalse(assetHub.supportsMetadataHash())
    }

    // MARK: Signed extensions

    func testSignedExtensionIdentifiers() throws {
        XCTAssertEqual(try describeExtensions(of: .westend()), "CheckNonZeroSender=660;CheckSpecVersion=661;CheckTxVersion=662;CheckGenesis=663;CheckMortality=664;CheckNonce=666;CheckWeight=667;ChargeTransactionPayment=668")
        XCTAssertEqual(try describeExtensions(of: .bittensor()), "CheckNonZeroSender=578;CheckSpecVersion=579;CheckTxVersion=580;CheckGenesis=581;CheckMortality=582;CheckNonce=584;CheckWeight=585;ChargeTransactionPayment=588;SudoTransactionExtension=589;CheckShieldedTxValidity=590;SubtensorTransactionExtension=591;DrandPriority=592;CheckMetadataHash=593")
        XCTAssertEqual(try describeExtensions(of: .polkadotAssetHub()), "AuthorizeCall=1047;CheckNonZeroSender=1048;CheckSpecVersion=1049;CheckTxVersion=1050;CheckGenesis=1051;CheckMortality=1052;CheckNonce=1054;CheckWeight=1055;ChargeAssetTxPayment=1056;PrevalidateAttests=1057;CheckMetadataHash=1058;EthSetOrigin=1060;StorageWeightReclaim=39")
        XCTAssertEqual(try describeExtensions(of: .avail()), "CheckNonZeroSender=508;CheckSpecVersion=509;CheckTxVersion=510;CheckGenesis=511;CheckMortality=512;CheckNonce=514;CheckWeight=515;ChargeTransactionPayment=516;CheckAppId=517")
    }

    func testUnknownSignedExtensionHasNoType() throws {
        let runtime = try ExtrinsicGoldenRuntime.westend()

        XCTAssertNil(runtime.metadata.getSignedExtensionType(for: "ChargeAssetTxPayment"))
    }

    // MARK: Lookups

    func testCallLookup() throws {
        XCTAssertEqual(try describeCall(in: .westend(), module: "Balances", call: "transfer_keep_alive"), "4.3 transfer_keep_alive(dest:198,value:50)")
        XCTAssertEqual(try describeCall(in: .bittensor(), module: "Balances", call: "transfer_keep_alive"), "5.3 transfer_keep_alive(dest:181,value:183)")
        XCTAssertEqual(try describeCall(in: .westend(), module: "Utility", call: "batch_all"), "16.2 batch_all(calls:287)")
        XCTAssertEqual(try describeCall(in: .bittensor(), module: "SubtensorModule", call: "add_stake"), "7.2 add_stake(hotkey:0,netuid:41,amount_staked:6)")
    }

    func testMissingCallLookup() throws {
        let metadata = try ExtrinsicGoldenRuntime.westend().metadata

        XCTAssertNil(metadata.getCall(from: "Balances", with: "no_such_call"))
        XCTAssertNil(metadata.getCall(from: "NoSuchPallet", with: "transfer"))
        XCTAssertNil(metadata.getModuleIndex("NoSuchPallet"))
        XCTAssertNil(metadata.getCallIndex(in: "Balances", callName: "no_such_call"))
    }

    func testEventLookup() throws {
        XCTAssertEqual(try describeEvent(in: .westend(), module: "System", eventIndex: 0), "System.ExtrinsicSuccess(19)")
        XCTAssertEqual(try describeEvent(in: .westend(), module: "Balances", eventIndex: 2), "Balances.Transfer(0,0,6)")
        XCTAssertEqual(try describeEvent(in: .bittensor(), module: "System", eventIndex: 1), "System.ExtrinsicFailed(27,24)")
    }

    func testConstantLookupAndDecoding() throws {
        XCTAssertEqual(try describeConstant(in: .westend(), module: "Balances", constant: "ExistentialDeposit"), #"6|0x00e40b54020000000000000000000000|"10000000000""#)
        XCTAssertEqual(try describeConstant(in: .westend(), module: "System", constant: "SS58Prefix"), #"68|0x2a00|"42""#)
        XCTAssertEqual(try describeConstant(in: .bittensor(), module: "Balances", constant: "ExistentialDeposit"), #"6|0xf401000000000000|"500""#)
    }

    func testStorageLookup() throws {
        XCTAssertEqual(try describeStorage(in: .westend(), module: "System", item: "Account"), "Account|defaultModifier|3|0x0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
        XCTAssertEqual(try describeStorage(in: .westend(), module: "System", item: "Events"), "Events|defaultModifier|15|0x00")
        XCTAssertEqual(try describeStorage(in: .bittensor(), module: "System", item: "Account"), "Account|defaultModifier|3|0x0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080")
    }

    func testRuntimeApiLookupRequiresV15() throws {
        let westend = try ExtrinsicGoldenRuntime.westend().metadata
        let bittensor = try ExtrinsicGoldenRuntime.bittensor().metadata

        let method = try XCTUnwrap(bittensor.getRuntimeApiMethod(for: "TransactionPaymentApi", methodName: "query_info"))
        let inputs = method.method.inputs.map { "\($0.name):\($0.paramType)" }.joined(separator: ",")

        XCTAssertNil(westend.getRuntimeApiMethod(for: "TransactionPaymentApi", methodName: "query_info"))
        XCTAssertEqual("\(method.callName)(\(inputs))->\(method.method.output)", "TransactionPaymentApi_query_info(uxt:597,len:4)->627")
    }

    // MARK: Type registry

    func testTypeRegistryResolvesKnownTypes() throws {
        let westend = try ExtrinsicGoldenRuntime.westend().codingFactory
        let bittensor = try ExtrinsicGoldenRuntime.bittensor().codingFactory

        XCTAssertEqual(describeNodes(in: westend), "Balance=U128Node:u128;Index=U32Node:u32;Address=SiVariantNode:sp_runtime.multiaddress.MultiAddress;ExtrinsicSignature=SiVariantNode:sp_runtime.MultiSignature;GenericCall=GenericCallNode:GenericCall;GenericEvent=GenericEventNode:GenericEvent;AppGenericExtrinsic=ExtrinsicNode:AppGenericExtrinsic;GenericAccountId=GenericAccountIdNode:GenericAccountId;Era=EraNode:Era")
        XCTAssertEqual(describeNodes(in: bittensor), "Balance=U128Node:u128;Index=U32Node:u32;Address=SiVariantNode:sp_runtime.multiaddress.MultiAddress;ExtrinsicSignature=SiVariantNode:sp_runtime.MultiSignature;GenericCall=GenericCallNode:GenericCall;GenericEvent=GenericEventNode:GenericEvent;AppGenericExtrinsic=ExtrinsicNode:AppGenericExtrinsic;GenericAccountId=GenericAccountIdNode:GenericAccountId;Era=EraNode:Era")
        XCTAssertFalse(westend.hasType(for: "no.such.Type"))
        XCTAssertNil(westend.getTypeNode(for: "no.such.Type"))
    }

    func testRuntimeJsonContextPrefersMultiAddress() throws {
        XCTAssertFalse(try ExtrinsicGoldenRuntime.westend().codingFactory.createRuntimeJsonContext().prefersRawAddress)
        XCTAssertFalse(try ExtrinsicGoldenRuntime.bittensor().codingFactory.createRuntimeJsonContext().prefersRawAddress)
    }

    func testRegistryEncodesAndDecodesKnownTypes() throws {
        let factory = try ExtrinsicGoldenRuntime.westend().codingFactory
        let address = try MultiAddress.accoundId(ExtrinsicGolden.senderId).toScaleCompatibleJSON(
            with: factory.createRuntimeJsonContext().toRawContext()
        )

        XCTAssertEqual(try encode(.stringValue("1000000000000"), type: KnownType.balance.name, factory: factory), "0x0010a5d4e80000000000000000000000")
        XCTAssertEqual(try encode(address, type: KnownType.address.name, factory: factory), "0x001111111111111111111111111111111111111111111111111111111111111111")
        XCTAssertEqual(try encode(.stringValue("7"), type: KnownType.index.name, factory: factory), "0x07000000")
        XCTAssertEqual(try decode("0x00a0724e180900000000000000000000", type: KnownType.balance.name, factory: factory), #""10000000000000""#)
    }
}

// MARK: Behaviour that substrate-sdk-ios 5 changed on purpose

extension RuntimeMetadataCharacterizationTests {
    /// SCALE encodes `Option<bool>` in one byte: None = 0, Some(true) = 1, Some(false) = 2.
    /// substrate-sdk-ios 4.5.2 had the two `Some` cases swapped; 5.x follows the specification
    /// (SDK commit "fix scale bool option"). Added after the bump, so it pins the corrected coding only.
    func testOptionalBoolFollowsScaleSpecification() throws {
        let factory = try ExtrinsicGoldenRuntime.westend().codingFactory

        XCTAssertEqual(try encodeOptionalBool(.boolValue(true), factory: factory), "0x01")
        XCTAssertEqual(try encodeOptionalBool(.boolValue(false), factory: factory), "0x02")
        XCTAssertEqual(try encodeOptionalBool(.null, factory: factory), "0x00")
        XCTAssertEqual(try factory.createDecoder(from: Data([1])).readOption(type: Self.boolType), .boolValue(true))
        XCTAssertEqual(try factory.createDecoder(from: Data([2])).readOption(type: Self.boolType), .boolValue(false))
        XCTAssertEqual(try factory.createDecoder(from: Data([0])).readOption(type: Self.boolType), .null)
    }
}

private extension RuntimeMetadataCharacterizationTests {
    static let boolType = "bool"

    func encodeOptionalBool(_ json: JSON, factory: RuntimeCoderFactoryProtocol) throws -> String {
        let encoder = factory.createEncoder()
        try encoder.appendOption(json: json, type: Self.boolType)

        return try encoder.encode().toHex(includePrefix: true)
    }

    func describeExtensions(of runtime: ExtrinsicGoldenRuntime) throws -> String {
        runtime.metadata.getSignedExtensions().map { identifier in
            "\(identifier)=\(runtime.metadata.getSignedExtensionType(for: identifier) ?? "nil")"
        }
        .joined(separator: ";")
    }

    func describeCall(in runtime: ExtrinsicGoldenRuntime, module: String, call: String) throws -> String {
        let metadata = runtime.metadata
        let callMetadata = try XCTUnwrap(metadata.getCall(from: module, with: call))
        let moduleIndex = try XCTUnwrap(metadata.getModuleIndex(module))
        let callIndex = try XCTUnwrap(metadata.getCallIndex(in: module, callName: call))
        let byIndex = try XCTUnwrap(metadata.getCallByModuleIndex(moduleIndex, callIndex: callIndex))
        let arguments = callMetadata.arguments.map { "\($0.name):\($0.type)" }.joined(separator: ",")

        XCTAssertEqual(byIndex.name, callMetadata.name)
        XCTAssertEqual(metadata.getModuleName(by: moduleIndex), module)
        XCTAssertNotNil(runtime.codingFactory.getCall(for: CallCodingPath(moduleName: module, callName: call)))

        return "\(moduleIndex).\(callIndex) \(callMetadata.name)(\(arguments))"
    }

    func describeEvent(in runtime: ExtrinsicGoldenRuntime, module: String, eventIndex: UInt32) throws -> String {
        let moduleIndex = try XCTUnwrap(runtime.metadata.getModuleIndex(module))
        let event = try XCTUnwrap(runtime.metadata.getEventForModuleIndex(moduleIndex, eventIndex: eventIndex))
        let optionalPath: EventCodingPath? = runtime.metadata.createEventCodingPath(
            from: moduleIndex,
            eventIndex: eventIndex
        )
        let path = try XCTUnwrap(optionalPath)

        return "\(path.moduleName).\(path.eventName)(\(event.arguments.joined(separator: ",")))"
    }

    func describeConstant(in runtime: ExtrinsicGoldenRuntime, module: String, constant: String) throws -> String {
        let metadata = try XCTUnwrap(runtime.metadata.getConstant(in: module, constantName: constant))
        let decoder = try runtime.codingFactory.createDecoder(from: metadata.value)
        let value = try ExtrinsicGolden.json(decoder.read(type: metadata.type))

        XCTAssertNotNil(
            runtime.codingFactory.getConstant(for: ConstantCodingPath(moduleName: module, constantName: constant))
        )

        return "\(metadata.type)|\(metadata.value.toHex(includePrefix: true))|\(value)"
    }

    func describeStorage(in runtime: ExtrinsicGoldenRuntime, module: String, item: String) throws -> String {
        let entry = try XCTUnwrap(runtime.metadata.getStorageMetadata(in: module, storageName: item))

        return "\(entry.name)|\(entry.modifier)|\(entry.type.typeName)|\(entry.defaultValue.toHex(includePrefix: true))"
    }

    func describeNodes(in factory: RuntimeCoderFactoryProtocol) -> String {
        let names = [
            KnownType.balance.name,
            KnownType.index.name,
            KnownType.address.name,
            KnownType.signature.name,
            KnownType.call.name,
            KnownType.event.name,
            GenericType.extrinsic.name,
            GenericType.accountId.name,
            GenericType.era.name
        ]

        return names.map { name in
            let node = factory.getTypeNode(for: name).map { "\(type(of: $0)):\($0.typeName)" } ?? "nil"
            return "\(name)=\(node)"
        }
        .joined(separator: ";")
    }

    func encode(_ json: JSON, type: String, factory: RuntimeCoderFactoryProtocol) throws -> String {
        let encoder = factory.createEncoder()
        try encoder.append(json: json, type: type)

        return try encoder.encode().toHex(includePrefix: true)
    }

    func decode(_ hex: String, type: String, factory: RuntimeCoderFactoryProtocol) throws -> String {
        let decoder = try factory.createDecoder(from: Data(hexString: hex))

        return try ExtrinsicGolden.json(decoder.read(type: type))
    }
}
