import BigInt
@testable import novawallet
import SubstrateSdk
import XCTest

/// Pins the bytes `ExtrinsicBuilder` produces for V4 extrinsics on the Westend v14 fixture.
/// Golden values were recorded on substrate-sdk-ios 4.5.2; a diff after an SDK bump is a finding, not a typo.
final class ExtrinsicBuilderCharacterizationTests: XCTestCase {
    private var runtime: ExtrinsicGoldenRuntime!

    override func setUpWithError() throws {
        runtime = try ExtrinsicGoldenRuntime.westend()
    }

    func testSignedTransferExtrinsicAndSignedPayload() throws {
        let builder = try runtime.makeBuilder().adding(call: ExtrinsicGolden.transferCall())

        let signed = try runtime.sign(builder)

        XCTAssertEqual(signed.signedPayload, "0x0403002222222222222222222222222222222222222222222222222222222222222222070010a5d4e855001c002c2400000b000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
        XCTAssertEqual(signed.extrinsic, "0x41028400111111111111111111111111111111111111111111111111111111111111111101abababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababab55001c000403002222222222222222222222222222222222222222222222222222222222222222070010a5d4e8")
    }

    func testSignedBatchAllExtrinsicAndSignedPayload() throws {
        let builder = try runtime.makeBuilder()
            .adding(call: ExtrinsicGolden.transferCall())
            .adding(call: ExtrinsicGolden.transferCall(to: ExtrinsicGolden.thirdPartyId, amount: 5))

        let signed = try runtime.sign(builder)

        XCTAssertEqual(signed.signedPayload, "0x1002080403002222222222222222222222222222222222222222222222222222222222222222070010a5d4e804030033333333333333333333333333333333333333333333333333333333333333331455001c002c2400000b000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
        XCTAssertEqual(signed.extrinsic, "0xdd028400111111111111111111111111111111111111111111111111111111111111111101abababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababab55001c001002080403002222222222222222222222222222222222222222222222222222222222222222070010a5d4e8040300333333333333333333333333333333333333333333333333333333333333333314")
    }

    func testBatchTypeSelectsUtilityCall() throws {
        let atomic = try makeTwoCallBuilder().with(batchType: .atomic)
        let untilFail = try makeTwoCallBuilder().with(batchType: .untilFail)
        let ignoreFails = try makeTwoCallBuilder().with(batchType: .ignoreFails)

        XCTAssertEqual(try runtime.signatureParams(of: atomic).encodedCall.toHex(includePrefix: true), "0x1002080403002222222222222222222222222222222222222222222222222222222222222222070010a5d4e800010c5a5a5a")
        XCTAssertEqual(try runtime.signatureParams(of: untilFail).encodedCall.toHex(includePrefix: true), "0x1000080403002222222222222222222222222222222222222222222222222222222222222222070010a5d4e800010c5a5a5a")
        XCTAssertEqual(try runtime.signatureParams(of: ignoreFails).encodedCall.toHex(includePrefix: true), "0x1004080403002222222222222222222222222222222222222222222222222222222222222222070010a5d4e800010c5a5a5a")
    }

    func testShouldUseAtomicBatchFlagMapsToBatchType() throws {
        let atomic = try makeTwoCallBuilder().with(shouldUseAtomicBatch: true)
        let nonAtomic = try makeTwoCallBuilder().with(shouldUseAtomicBatch: false)

        XCTAssertEqual(
            try runtime.signatureParams(of: atomic).encodedCall,
            try runtime.signatureParams(of: makeTwoCallBuilder().with(batchType: .atomic)).encodedCall
        )
        XCTAssertEqual(
            try runtime.signatureParams(of: nonAtomic).encodedCall,
            try runtime.signatureParams(of: makeTwoCallBuilder().with(batchType: .untilFail)).encodedCall
        )
    }

    func testBatchingCallsCollapsesToSingleCall() throws {
        let builder = try makeTwoCallBuilder().batchingCalls(with: runtime.metadata)

        XCTAssertEqual(builder.getCalls().count, 1)
        XCTAssertEqual(try ExtrinsicGolden.json(builder.getCalls()), #"[{"args":{"calls":[{"args":{"dest":["Id","0x2222222222222222222222222222222222222222222222222222222222222222"],"value":"1000000000000"},"callName":"transfer_keep_alive","moduleName":"Balances"},{"args":{"remark":["90","90","90"]},"callName":"remark","moduleName":"System"}]},"callName":"batch_all","moduleName":"Utility"}]"#)
    }

    func testBareExtrinsicBytes() throws {
        let builder = try runtime.makeBuilder().adding(call: ExtrinsicGolden.transferCall())

        let extrinsic = try builder.build(using: runtime.codingFactory, metadata: runtime.metadata)

        XCTAssertEqual(extrinsic.toHex(includePrefix: true), "0xa8040403002222222222222222222222222222222222222222222222222222222222222222070010a5d4e8")
    }

    func testSignatureCryptoTypeIsEncodedInExtrinsic() throws {
        let ed25519 = try runtime.sign(makeTransferBuilder(), cryptoType: .ed25519)
        let ecdsa = try runtime.sign(
            makeTransferBuilder(),
            cryptoType: .ecdsa,
            signature: ExtrinsicGolden.ecdsaSignature
        )

        XCTAssertEqual(ed25519.extrinsic, "0x41028400111111111111111111111111111111111111111111111111111111111111111100abababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababab55001c000403002222222222222222222222222222222222222222222222222222222222222222070010a5d4e8")
        XCTAssertEqual(ecdsa.extrinsic, "0x45028400111111111111111111111111111111111111111111111111111111111111111102cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd55001c000403002222222222222222222222222222222222222222222222222222222222222222070010a5d4e8")
    }

    func testImmortalEraAndTipExtrinsic() throws {
        let builder = try runtime.makeBuilder(era: .immortal)
            .with(tip: BigUInt(123_456_789))
            .adding(call: ExtrinsicGolden.transferCall())

        let signed = try runtime.sign(builder)

        XCTAssertEqual(signed.signedPayload, "0x0403002222222222222222222222222222222222222222222222222222222222222222070010a5d4e8001c56346f1d2c2400000b000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
        XCTAssertEqual(signed.extrinsic, "0x49028400111111111111111111111111111111111111111111111111111111111111111101abababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababab001c56346f1d0403002222222222222222222222222222222222222222222222222222222222222222070010a5d4e8")
    }

    func testRawCallProducesSameExtrinsicAsTypedCall() throws {
        let typed = try makeTransferBuilder()
        let callJson = try XCTUnwrap(typed.getCalls().first)
        let rawCall = try Data(hexString: runtime.encodeCall(callJson))

        let raw = try runtime.makeBuilder().adding(rawCall: rawCall)

        XCTAssertEqual(try runtime.encodeCall(callJson), "0x0403002222222222222222222222222222222222222222222222222222222222222222070010a5d4e8")
        XCTAssertEqual(try runtime.sign(raw).extrinsic, try runtime.sign(typed).extrinsic)
    }

    func testCallsAccessorsKeepInsertionOrder() throws {
        let builder = try runtime.makeBuilder()
            .adding(call: ExtrinsicGolden.transferCall())
            .adding(call: ExtrinsicGolden.remarkCall(size: 2), at: 0)

        XCTAssertEqual(try ExtrinsicGolden.json(builder.getCalls()), #"[{"args":{"remark":["90","90"]},"callName":"remark","moduleName":"System"},{"args":{"dest":["Id","0x2222222222222222222222222222222222222222222222222222222222222222"],"value":"1000000000000"},"callName":"transfer_keep_alive","moduleName":"Balances"}]"#)
        XCTAssertEqual(builder.getNonce(), ExtrinsicGolden.nonce)
        XCTAssertTrue(builder.resetCalls().getCalls().isEmpty)
    }

    func testAddingCallOutOfBoundsThrows() throws {
        let builder = try runtime.makeBuilder()

        XCTAssertThrowsError(try builder.adding(call: ExtrinsicGolden.transferCall(), at: 1)) { error in
            guard case ExtrinsicBuilderError.indexOutOfBounds = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testBuildingWithoutCallsThrowsMissingCall() throws {
        let builder = try runtime.makeBuilder()

        XCTAssertThrowsError(try runtime.signaturePayload(of: builder)) { error in
            guard case ExtrinsicBuilderError.missingCall = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testSigningWithoutAddressThrowsMissingAddress() throws {
        let builder = try ExtrinsicBuilder(
            specVersion: runtime.codingFactory.specVersion,
            transactionVersion: runtime.codingFactory.txVersion,
            genesisHash: ExtrinsicGolden.genesisHash
        )
        .with(runtimeJsonContext: runtime.codingFactory.createRuntimeJsonContext())
        .adding(call: ExtrinsicGolden.transferCall())

        XCTAssertThrowsError(try runtime.sign(builder)) { error in
            guard case ExtrinsicBuilderError.missingAddress = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testWrappingCallsReplacesEveryCall() throws {
        let remark = try ExtrinsicGolden.remarkCall(size: 1).toScaleCompatibleJSON(
            with: runtime.codingFactory.createRuntimeJsonContext().toRawContext()
        )

        let builder = try makeTwoCallBuilder().wrappingCalls { _ in remark }

        XCTAssertEqual(builder.getCalls(), [remark, remark])
    }
}

private extension ExtrinsicBuilderCharacterizationTests {
    func makeTransferBuilder() throws -> ExtrinsicBuilderProtocol {
        try runtime.makeBuilder().adding(call: ExtrinsicGolden.transferCall())
    }

    func makeTwoCallBuilder() throws -> ExtrinsicBuilderProtocol {
        try runtime.makeBuilder()
            .adding(call: ExtrinsicGolden.transferCall())
            .adding(call: ExtrinsicGolden.remarkCall(size: 3))
    }
}
