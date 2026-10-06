import Foundation
import BigInt
import Cuckoo
import Operation_iOS
import SubstrateSdk
import XCTest
@testable import novawallet

struct SubtensorFlowSubmission {
    let outcome: SubtensorStakingOperationOutcome
    let calls: [String]
}

enum SubtensorFlowExtrinsic {
    static let extrinsicHash = "0x" + String(repeating: "07", count: 32)
    static let blockHash = "0x" + String(repeating: "08", count: 32)

    static func stakeAdded(
        hotkey: AccountId,
        netuid: UInt16,
        tao: UInt64,
        alpha: UInt64,
        poolFee: UInt64
    ) -> String {
        "0702" + SubtensorFlowChainWorld.coldkey.toHex() + hotkey.toHex() + le(tao) + le(alpha) + le(netuid) + le(poolFee)
    }

    static func stakeRemoved(
        hotkey: AccountId,
        netuid: UInt16,
        tao: UInt64,
        alpha: UInt64,
        poolFee: UInt64
    ) -> String {
        "0703" + SubtensorFlowChainWorld.coldkey.toHex() + hotkey.toHex() + le(tao) + le(alpha) + le(netuid) + le(poolFee)
    }

    static func transfer(to receiver: AccountId, amount: UInt64) -> String {
        "0502" + SubtensorFlowChainWorld.coldkey.toHex() + receiver.toHex() + le(amount)
    }

    static func networkFeePaid(_ fee: UInt64) -> String {
        "0600" + SubtensorFlowChainWorld.coldkey.toHex() + le(fee) + le(UInt64(0))
    }

    static func addStake(hotkey: AccountId, netuid: UInt16, amount: UInt64) -> String {
        "0702" + hotkey.toHex() + le(netuid) + le(amount)
    }

    static func removeStake(hotkey: AccountId, netuid: UInt16, amount: UInt64) -> String {
        "0703" + hotkey.toHex() + le(netuid) + le(amount)
    }

    static func addStakeLimit(hotkey: AccountId, netuid: UInt16, amount: UInt64, limitPrice: UInt64) -> String {
        "0758" + hotkey.toHex() + le(netuid) + le(amount) + le(limitPrice) + "00"
    }

    static func removeStakeLimit(hotkey: AccountId, netuid: UInt16, alpha: UInt64, limitPrice: UInt64) -> String {
        "0759" + hotkey.toHex() + le(netuid) + le(alpha) + le(limitPrice) + "00"
    }

    static func removeStakeFullLimit(hotkey: AccountId, netuid: UInt16, limitPrice: UInt64) -> String {
        "0767" + hotkey.toHex() + le(netuid) + "01" + le(limitPrice)
    }

    static func transferKeepAlive(to receiver: AccountId, amount: Balance) throws -> String {
        let encoder = ScaleEncoder()
        try amount.encode(scaleEncoder: encoder)

        return "050300" + receiver.toHex() + encoder.encode().toHex()
    }

    static func batchAll(_ calls: [String]) -> String {
        "0b02" + le(UInt8(calls.count << 2)) + calls.joined()
    }

    static func le<T: FixedWidthInteger>(_ value: T) -> String {
        withUnsafeBytes(of: value.littleEndian) { Data($0) }.toHex()
    }
}

extension SubtensorFlowTestCase {
    func submit(
        _ operation: SubtensorStakingOperation,
        in world: SubtensorFlowWorld,
        events eventsHex: [String]
    ) throws -> SubtensorFlowSubmission {
        let codingFactory = try world.useBittensorRuntime()
        let recorder = SubtensorFlowBuilderRecorder()

        let submission = ExtrinsicMonitorSubmission(
            extrinsicSubmittedModel: ExtrinsicSubmittedModel(
                txHash: SubtensorFlowExtrinsic.extrinsicHash,
                sender: .current(SubtensorFlowChainWorld.coldkeyAccount().chainAccount)
            ),
            status: .success(.init(
                extrinsicHash: SubtensorFlowExtrinsic.extrinsicHash,
                blockHash: SubtensorFlowExtrinsic.blockHash,
                interestedEvents: try decodeEvents(eventsHex, codingFactory: codingFactory)
            ))
        )

        let submitMonitor = MockExtrinsicSubmitMonitorFactoryProtocol()

        stub(submitMonitor) { stub in
            when(stub.submitAndMonitorWrapper(
                extrinsicBuilderClosure: any(),
                payingIn: any(),
                signer: any(),
                matchingEvents: any()
            )).then { builderClosure, _, _, _ in
                recorder.record(builderClosure)

                return CompoundOperationWrapper.createWithResult(submission)
            }
        }

        let service = try world.createStakingOperationService(networkFee: networkFee, submitMonitor: submitMonitor)
        let outcome = try run(service.createSubmitWrapper(for: operation) {})

        return SubtensorFlowSubmission(
            outcome: outcome,
            calls: try encodeCalls(of: try XCTUnwrap(recorder.closures.first), codingFactory: codingFactory)
        )
    }
}

private final class SubtensorFlowBuilderRecorder {
    private let lock = NSLock()
    private var recordedClosures: [ExtrinsicBuilderClosure] = []

    var closures: [ExtrinsicBuilderClosure] {
        lock.lock()
        defer { lock.unlock() }
        return recordedClosures
    }

    func record(_ closure: @escaping ExtrinsicBuilderClosure) {
        lock.lock()
        recordedClosures.append(closure)
        lock.unlock()
    }
}

private extension SubtensorFlowTestCase {
    func decodeEvents(_ eventsHex: [String], codingFactory: RuntimeCoderFactoryProtocol) throws -> [Event] {
        let entry = try XCTUnwrap(codingFactory.metadata.getStorageMetadata(for: SystemPallet.eventsPath))

        let recordsHex = SubtensorFlowExtrinsic.le(UInt8(eventsHex.count << 2)) +
            eventsHex.map { "00" + "00000000" + $0 + "00" }.joined()

        let decoder = try codingFactory.createDecoder(from: Data(hexString: recordsHex))
        let json = try decoder.read(type: entry.type.typeName)

        return try json.map(
            to: [EventRecord].self,
            with: codingFactory.createRuntimeJsonContext().toRawContext()
        ).map(\.event)
    }

    func encodeCalls(
        of builderClosure: ExtrinsicBuilderClosure,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> [String] {
        let builder = try builderClosure(
            ExtrinsicBuilder().with(runtimeJsonContext: codingFactory.createRuntimeJsonContext())
        ).batchingCalls(with: codingFactory.metadata)

        return try builder.getCalls().map { call in
            let encoder = codingFactory.createEncoder()
            try encoder.append(json: call, type: GenericType.call.name)
            return try encoder.encode().toHex()
        }
    }
}
