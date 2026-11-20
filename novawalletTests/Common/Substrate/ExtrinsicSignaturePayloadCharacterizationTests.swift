import BigInt
@testable import novawallet
import SubstrateSdk
import XCTest

/// Pins what the signer receives: the three `ExtrinsicSignaturePayloadFormat` cases, the raw signature path,
/// the signature params used for hardware signing and the builder memo round trip.
/// Golden values were recorded on substrate-sdk-ios 4.5.2.
final class ExtrinsicSignaturePayloadCharacterizationTests: XCTestCase {
    /// SCALE payloads above this size are replaced by their blake2b-256 hash in the `regular` format.
    private static let hashingThreshold = 256

    private var runtime: ExtrinsicGoldenRuntime!

    override func setUpWithError() throws {
        runtime = try ExtrinsicGoldenRuntime.westend()
    }

    func testRegularFormatSignsRawPayloadBelowThreshold() throws {
        let builder = try makeTransferBuilder().with(signaturePayloadFormat: .regular)

        let payload = try runtime.signaturePayload(of: builder)

        XCTAssertEqual(payload, "0x0403002222222222222222222222222222222222222222222222222222222222222222070010a5d4e855001c002c2400000b000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
        XCTAssertEqual(payload, try runtime.signaturePayload(of: makeTransferBuilder()))
    }

    func testRegularFormatSignsHashAboveThreshold() throws {
        let regular = try makeLargeBuilder().with(signaturePayloadFormat: .regular)
        let notHashed = try makeLargeBuilder().with(signaturePayloadFormat: .extrinsicPayload)

        let regularPayload = try Data(hexString: runtime.signaturePayload(of: regular))
        let fullPayload = try Data(hexString: runtime.signaturePayload(of: notHashed))

        XCTAssertGreaterThan(fullPayload.count, Self.hashingThreshold)
        XCTAssertEqual(regularPayload, try fullPayload.blake2b32())
        XCTAssertEqual(regularPayload.toHex(includePrefix: true), "0x2a29eefe68399ec097a9e1eef7b76c05a68ab2b983f5dc65a743f610afec6b1f")
        XCTAssertEqual(fullPayload.toHex(includePrefix: true), "0x0001b1045a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a55001c002c2400000b000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
    }

    func testHashingAppliesStrictlyAboveThreshold() throws {
        let exact = Data(repeating: 1, count: Self.hashingThreshold)
        let above = Data(repeating: 1, count: Self.hashingThreshold + 1)

        XCTAssertEqual(try ExtrinsicSignatureConverter.convertExtrinsicPayloadToRegular(exact), exact)
        XCTAssertEqual(try ExtrinsicSignatureConverter.convertExtrinsicPayloadToRegular(above), try above.blake2b32())
    }

    func testExtrinsicPayloadFormatMatchesRegularBelowThreshold() throws {
        let builder = try makeTransferBuilder().with(signaturePayloadFormat: .extrinsicPayload)

        XCTAssertEqual(
            try runtime.signaturePayload(of: builder),
            try runtime.signaturePayload(of: makeTransferBuilder())
        )
    }

    func testParitySignerFormatPrefixesCallWithItsLength() throws {
        let builder = try makeTransferBuilder().with(signaturePayloadFormat: .paritySigner)

        let payload = try runtime.signaturePayload(of: builder)

        XCTAssertEqual(payload, "0xa40403002222222222222222222222222222222222222222222222222222222222222222070010a5d4e855001c002c2400000b000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
    }

    func testParitySignerPayloadConvertsBackToRegular() throws {
        let paritySigner = try makeTransferBuilder().with(signaturePayloadFormat: .paritySigner)
        let payload = try Data(hexString: runtime.signaturePayload(of: paritySigner))

        let regular = try ExtrinsicSignatureConverter.convertParitySignerSignaturePayloadToRegular(payload)

        XCTAssertEqual(regular.toHex(includePrefix: true), try runtime.signaturePayload(of: makeTransferBuilder()))
    }

    func testParitySignerFormatIsNotHashedAboveThreshold() throws {
        let builder = try makeLargeBuilder().with(signaturePayloadFormat: .paritySigner)

        let payload = try Data(hexString: runtime.signaturePayload(of: builder))

        XCTAssertGreaterThan(payload.count, Self.hashingThreshold)
        XCTAssertEqual(payload.toHex(includePrefix: true), "0xc1040001b1045a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a55001c002c2400000b000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
    }

    func testBuildRawSignatureHandsPayloadToSignerAndReturnsItsOutput() throws {
        let builder = try makeTransferBuilder()
        var receivedPayload = Data()

        let signature = try builder.buildRawSignature(
            using: { payload in
                receivedPayload = payload
                return ExtrinsicGolden.sr25519Signature
            },
            encodingFactory: runtime.codingFactory,
            metadata: runtime.metadata
        )

        XCTAssertEqual(signature, ExtrinsicGolden.sr25519Signature)
        XCTAssertEqual(receivedPayload.toHex(includePrefix: true), try runtime.signaturePayload(of: builder))
    }

    func testBuildExtrinsicSignatureParams() throws {
        let params = try runtime.signatureParams(of: makeTransferBuilder())

        XCTAssertEqual(params.encodedCall.toHex(includePrefix: true), "0x0403002222222222222222222222222222222222222222222222222222222222222222070010a5d4e8")
        XCTAssertEqual(params.includedInExtrinsicExtra.toHex(includePrefix: true), "0x55001c00")
        XCTAssertEqual(params.includedInSignatureExtra.toHex(includePrefix: true), "0x2c2400000b000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
    }

    func testSignatureParamsConcatenateIntoSignedPayload() throws {
        let builder = try makeTransferBuilder()
        let params = try runtime.signatureParams(of: builder)

        let concatenated = params.encodedCall + params.includedInExtrinsicExtra + params.includedInSignatureExtra

        XCTAssertEqual(concatenated.toHex(includePrefix: true), try runtime.signaturePayload(of: builder))
    }

    func testMemoRestoresBuilderWithSamePayloadAndExtrinsic() throws {
        let builder = try makeTransferBuilder()
            .with(tip: BigUInt(42))
            .with(signaturePayloadFormat: .paritySigner)

        let restored = builder.makeMemo().restoreBuilder()

        XCTAssertEqual(try runtime.signaturePayload(of: restored), try runtime.signaturePayload(of: builder))
        XCTAssertEqual(restored.getNonce(), ExtrinsicGolden.nonce)
        XCTAssertEqual(restored.getCalls(), builder.getCalls())
        XCTAssertEqual(try runtime.sign(restored).extrinsic, try runtime.sign(builder).extrinsic)
    }

    func testMemoOfSignedBuilderKeepsSignedExtrinsic() throws {
        let builder = try makeTransferBuilder()
        let signed = try runtime.sign(builder)

        let restored = builder.makeMemo().restoreBuilder()
        let rebuilt = try restored.build(using: runtime.codingFactory, metadata: runtime.metadata)

        XCTAssertEqual(rebuilt.toHex(includePrefix: true), signed.extrinsic)
    }

    func testMemoRestoredBuilderIsIndependentFromOriginal() throws {
        let builder = try makeTransferBuilder()
        let originalPayload = try runtime.signaturePayload(of: builder)

        let restored = builder.makeMemo().restoreBuilder().with(nonce: ExtrinsicGolden.nonce + 1)

        XCTAssertEqual(try runtime.signaturePayload(of: builder), originalPayload)
        XCTAssertNotEqual(try runtime.signaturePayload(of: restored), originalPayload)
    }
}

private extension ExtrinsicSignaturePayloadCharacterizationTests {
    func makeTransferBuilder() throws -> ExtrinsicBuilderProtocol {
        try runtime.makeBuilder().adding(call: ExtrinsicGolden.transferCall())
    }

    /// A remark big enough to push the payload over the hashing threshold.
    func makeLargeBuilder() throws -> ExtrinsicBuilderProtocol {
        try runtime.makeBuilder().adding(call: ExtrinsicGolden.remarkCall(size: 300))
    }
}
