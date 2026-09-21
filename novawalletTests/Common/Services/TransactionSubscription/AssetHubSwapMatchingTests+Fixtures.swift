import XCTest
@testable import novawallet
import SubstrateSdk
import BigInt

/// A minimal, synthetic V13 runtime for history control-flow tests, not a deployed Asset Hub fixture.
/// Calls/extrinsics use the real SDK SCALE codec; events use the production JSON decoders.
struct AssetHubHistoryFixture {
    static let sender = AccountId(repeating: 5, count: 32)
    static let real = AccountId(repeating: 7, count: 32)
    static let other = AccountId(repeating: 6, count: 32)
    static let beneficiary = AccountId(repeating: 9, count: 32)
    static let path: [AssetConversionPallet.AssetId] = Array(
        repeating: .init(parents: 0, interior: .init(items: [])), count: 2
    )

    let codingFactory: RuntimeCoderFactoryProtocol
    let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 42)
    var context: RuntimeJsonContext { codingFactory.createRuntimeJsonContext() }

    init() throws {
        codingFactory = try Self.createCodingFactory()
    }

    func signed(_ call: AnyRuntimeCall) throws -> Extrinsic {
        let testSignature = ExtrinsicSignature(
            address: try MultiAddress.accoundId(Self.sender).toScaleCompatibleJSON(with: context.toRawContext()),
            // History decoding does not verify cryptographic signatures. Use a fixed SCALE Sr25519 payload.
            signature: .arrayValue([.stringValue("Sr25519"), .stringValue(Data(repeating: 0, count: 64).toHex())]),
            extra: [:]
        )
        return .signed(.init(
            signature: testSignature,
            call: try call.toScaleCompatibleJSON(with: context.toRawContext())
        ))
    }

    func records(_ events: [Event]) throws -> [EventRecord] {
        try events.map { event in
            let json: JSON = .dictionaryValue([
                "phase": .arrayValue([.stringValue("ApplyExtrinsic"), .stringValue("2")]),
                "event": .arrayValue([.unsignedIntValue(UInt64(event.moduleIndex)),
                                      .unsignedIntValue(UInt64(event.eventIndex)), event.params])
            ])
            return try json.map(to: EventRecord.self)
        }
    }

    func process(
        _ call: AnyRuntimeCall,
        account: AccountId,
        events: [Event],
        beneficiaries: Set<AccountId> = [Self.beneficiary]
    ) throws -> ExtrinsicProcessingResult? {
        let encoder = codingFactory.createEncoder()
        try encoder.append(signed(call), ofType: GenericType.extrinsic.name)
        let processor = ExtrinsicProcessor(
            accountId: account, chain: chain, assetHubCommissionBeneficiaries: beneficiaries
        )
        return processor.process(
            extrinsicIndex: 2,
            extrinsicData: try encoder.encode(),
            eventRecords: try records(events),
            coderFactory: codingFactory
        )
    }

    func swap(receiver: AccountId) throws -> AnyRuntimeCall {
        try AssetConversionPallet.SwapExactTokensForTokensCall(
            path: Self.path, amountIn: 1000, amountOutMin: 900, sendTo: receiver, keepAlive: false
        ).runtimeCall(for: AssetConversionPallet.name).anyRuntimeCall(with: context)
    }

    func collection(beneficiary: AccountId = Self.beneficiary) throws -> AnyRuntimeCall {
        try SubstrateCallFactory().nativeTransfer(to: beneficiary, amount: 10, callPath: .transferKeepAlive)
            .anyRuntimeCall(with: context)
    }

    func batch(_ calls: [AnyRuntimeCall], path: CallCodingPath = UtilityPallet.batchAllPath) throws -> AnyRuntimeCall {
        try AnyRuntimeCall(path: path, args: UtilityPallet.Call(calls: calls), context: context)
    }

    func charged(receiver: AccountId) throws -> AnyRuntimeCall {
        try batch([swap(receiver: receiver), collection()])
    }

    func proxy(_ call: AnyRuntimeCall, real: AccountId) throws -> AnyRuntimeCall {
        try Proxy.ProxyCall(
            real: .accoundId(real),
            forceProxyType: .any,
            call: call.toScaleCompatibleJSON(with: context.toRawContext())
        )
        .runtimeCall().anyRuntimeCall(with: context)
    }

    func multisig(_ call: AnyRuntimeCall) throws -> AnyRuntimeCall {
        try MultisigPallet.AsMultiCall(
            threshold: 2, otherSignatories: [BytesCodable(wrappedValue: Self.other)], maybeTimepoint: nil,
            call: call.toScaleCompatibleJSON(with: context.toRawContext()),
            maxWeight: Substrate.Weight(refTime: 1000, proofSize: 1000)
        ).runtimeCall().anyRuntimeCall(with: context)
    }

    func thresholdOne(_ call: AnyRuntimeCall) throws -> AnyRuntimeCall {
        try MultisigPallet.AsMultiThreshold1Call(
            otherSignatories: [BytesCodable(wrappedValue: Self.other)],
            call: call.toScaleCompatibleJSON(with: context.toRawContext())
        ).runtimeCall().anyRuntimeCall(with: context)
    }

    func event(_ path: EventCodingPath, params: [JSON] = []) throws -> Event {
        let module = try XCTUnwrap(codingFactory.metadata.getModuleIndex(path.moduleName))
        let index = try XCTUnwrap((0 ..< 100).first {
            codingFactory.metadata.getEventForModuleIndex(module, eventIndex: UInt32($0))?.name == path.eventName
        })
        return try JSON.arrayValue([.unsignedIntValue(UInt64(module)), .unsignedIntValue(UInt64(index)),
                                    .arrayValue(params)]).map(to: Event.self)
    }

    func system(success: Bool = true) throws -> Event {
        try event(success ? SystemPallet.extrinsicSuccessEventPath : SystemPallet.extrinsicFailedEventPath)
    }

    func fee() throws -> Event {
        try event(BalancesPallet.balancesWithdraw, params: [.stringValue(Self.sender.toHex()), .stringValue("1")])
    }

    func proxyEvent(success: Bool) throws -> Event {
        try event(Proxy.executedEventPath, params: [Self.result(success)])
    }

    func multisigEvent(
        call: AnyRuntimeCall,
        origin: AccountId,
        success: Bool,
        hash: Data? = nil,
        approver: AccountId = Self.sender
    ) throws -> Event {
        let encoder = codingFactory.createEncoder()
        try encoder.append(json: call.toScaleCompatibleJSON(with: context.toRawContext()), type: GenericType.call.name)
        let callHash = try hash ?? encoder.encode().blake2b32()
        return try event(MultisigPallet.multisigExecutedEventPath, params: [
            .stringValue(approver.toHex()), .arrayValue([.stringValue("1"), .stringValue("0")]),
            .stringValue(origin.toHex()), .stringValue(callHash.toHex()), Self.result(success)
        ])
    }

    func swapEvent(receiver: AccountId, amountOut: String = "950") throws -> Event {
        let path = try Self.path.map { asset in
            JSON.arrayValue([try asset.toScaleCompatibleJSON(), .stringValue("1000")])
        }
        return try event(AssetConversionPallet.swapExecutedEvent, params: [
            .stringValue(receiver.toHex()), .stringValue(receiver.toHex()), .stringValue("1000"),
            .stringValue(amountOut), .arrayValue(path)
        ])
    }

    func transferEvent(sender: AccountId, amount: String = "10") throws -> Event {
        try event(BalancesPallet.balancesTransfer, params: [
            .stringValue(sender.toHex()), .stringValue(Self.beneficiary.toHex()), .stringValue(amount)
        ])
    }

    private static func result(_ success: Bool) -> JSON {
        .arrayValue([.stringValue(success ? "Ok" : "Err"), .null])
    }
}

private extension AssetHubHistoryFixture {
    static func createCodingFactory() throws -> RuntimeCoderFactoryProtocol {
        var modules = [ModuleMetadata]()
        modules.append(ModuleMetadata(
            name: "Utility", storage: nil, calls: ["batch", "batch_all", "force_batch"].map {
                CallMetadata(name: $0, arguments: arguments([("calls", "Vec<Call>")]), documentation: [])
            }, events: [], constants: [], errors: [], index: 102
        ))
        modules.append(ModuleMetadata(
            name: "Proxy", storage: nil, calls: [CallMetadata(
                name: "proxy", arguments: arguments([
                    ("real", "Address"), ("force_proxy_type", "Option<ProxyType>"), ("call", "Call")
                ]), documentation: []
            )], events: [EventMetadata(name: "ProxyExecuted", arguments: [], documentation: [])],
            constants: [], errors: [], index: 103
        ))
        modules.append(ModuleMetadata(
            name: "Balances", storage: nil, calls: [CallMetadata(
                name: "transfer_keep_alive", arguments: arguments([("dest", "Address"), ("value", "Compact<Balance>")]),
                documentation: []
            )], events: ["Transfer", "Withdraw"].map { EventMetadata(name: $0, arguments: [], documentation: []) },
            constants: [], errors: [], index: 104
        ))
        modules.append(ModuleMetadata(
            name: "System", storage: nil, calls: [],
            events: ["ExtrinsicSuccess", "ExtrinsicFailed"].map {
                EventMetadata(name: $0, arguments: [], documentation: [])
            }, constants: [], errors: [], index: 105
        ))
        modules.append(ModuleMetadata(
            name: "AssetConversion", storage: nil, calls: [CallMetadata(
                name: "swap_exact_tokens_for_tokens", arguments: arguments([
                    ("path", "Vec<TestLocation>"), ("amount_in", "Compact<Balance>"),
                    ("amount_out_min", "Compact<Balance>"), ("send_to", "AccountId"), ("keep_alive", "bool")
                ]), documentation: []
            )], events: [EventMetadata(name: "SwapExecuted", arguments: [], documentation: [])],
            constants: [], errors: [], index: 100
        ))
        modules.append(ModuleMetadata(
            name: "Multisig", storage: nil, calls: [CallMetadata(
                name: "as_multi", arguments: arguments([
                    ("threshold", "u16"), ("other_signatories", "Vec<AccountId>"),
                    ("maybe_timepoint", "Option<Timepoint>"), ("call", "Call"), ("max_weight", "TestWeight")
                ]), documentation: []
            ), CallMetadata(name: "as_multi_threshold_1", arguments: arguments([
                ("other_signatories", "Vec<AccountId>"), ("call", "Call")
            ]), documentation: [])], events: [EventMetadata(name: "MultisigExecuted", arguments: [], documentation: [])],
            constants: [], errors: [], index: 101
        ))
        modules.append(ModuleMetadata(
            name: "ConfiguredAssets", storage: nil, calls: [],
            events: [EventMetadata(name: "Transferred", arguments: [], documentation: [])],
            constants: [], errors: [], index: 106
        ))
        let metadata = RuntimeMetadata(modules: modules, extrinsic: ExtrinsicMetadata(version: 4, signedExtensions: []))
        let baseURL = try XCTUnwrap(Bundle.main.url(forResource: "runtime-default", withExtension: "json"))
        var definition = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: baseURL)) as? [String: Any])
        var types = try XCTUnwrap(definition["types"] as? [String: Any])
        types["ProxyType"] = ["type": "enum", "type_mapping": [["Any", "Null"]]]
        types["TestLocation"] = ["type": "struct", "type_mapping": [["parents", "u8"], ["interior", "TestInterior"]]]
        types["TestInterior"] = ["type": "enum", "type_mapping": [["Here", "Null"]]]
        types["TestWeight"] = ["type": "struct", "type_mapping": [["refTime", "u64"], ["proofSize", "u64"]]]
        definition["types"] = types
        let catalog = try TypeRegistryCatalog.createFromTypeDefinition(
            JSONSerialization.data(withJSONObject: definition), runtimeMetadata: metadata
        )
        return RuntimeCoderFactory(catalog: catalog, specVersion: 9260, txVersion: 11, metadata: metadata)
    }

    static func arguments(_ values: [(String, String)]) -> [CallArgumentMetadata] {
        values.map { CallArgumentMetadata(name: $0.0, type: $0.1) }
    }
}
