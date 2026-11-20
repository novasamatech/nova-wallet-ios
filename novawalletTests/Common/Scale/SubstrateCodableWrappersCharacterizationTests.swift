import BigInt
@testable import novawallet
import SubstrateSdk
import XCTest

/// Pins the JSON shape of the SubstrateSdk property wrappers and `MultiSignature` the app's runtime models
/// are built from. The expected values are the literal JSON produced on substrate-sdk-ios 4.5.2.
final class SubstrateCodableWrappersCharacterizationTests: XCTestCase {
    private struct BytesModel: Codable, Equatable {
        @BytesCodable var value: Data
    }

    private struct StringModel: Codable, Equatable {
        @StringCodable var amount: BigUInt
        @StringCodable var index: UInt32
    }

    private struct OptionStringModel: Codable, Equatable {
        @OptionStringCodable var value: UInt32?
    }

    private struct NullModel: Codable, Equatable {
        @NullCodable var value: String?
    }

    // MARK: BytesCodable

    func testBytesCodableEncodesAsArrayOfStringBytes() throws {
        let model = BytesModel(value: Data([0, 1, 255]))

        XCTAssertEqual(try scaleJson(model), #"{"value":["0","1","255"]}"#)
    }

    func testBytesCodableDecodesByteArrayAndHexString() throws {
        let fromArray = try decode(BytesModel.self, #"{"value":["0","1","255"]}"#)
        let fromHex = try decode(BytesModel.self, #"{"value":"0x0001ff"}"#)

        XCTAssertEqual(fromArray.value, Data([0, 1, 255]))
        XCTAssertEqual(fromHex.value, Data([0, 1, 255]))
    }

    func testBytesCodableRejectsNumericByteArray() {
        XCTAssertThrowsError(try decode(BytesModel.self, #"{"value":[0,1,255]}"#))
    }

    func testBytesCodableEquatable() {
        XCTAssertEqual(BytesCodable(wrappedValue: Data([1])), BytesCodable(wrappedValue: Data([1])))
        XCTAssertNotEqual(BytesCodable(wrappedValue: Data([1])), BytesCodable(wrappedValue: Data([2])))
    }

    // MARK: StringCodable

    func testStringCodableEncodesNumbersAsDecimalStrings() throws {
        let model = StringModel(amount: (BigUInt(1) << 128) - 1, index: 7)

        XCTAssertEqual(
            try scaleJson(model),
            #"{"amount":"340282366920938463463374607431768211455","index":"7"}"#
        )
    }

    func testStringCodableDecodesOnlyDecimalStrings() throws {
        let model = try decode(StringModel.self, #"{"amount":"1000000000000","index":"7"}"#)

        XCTAssertEqual(model.amount, BigUInt(1_000_000_000_000))
        XCTAssertEqual(model.index, 7)
        XCTAssertThrowsError(try decode(StringModel.self, #"{"amount":1000,"index":"7"}"#))
        XCTAssertThrowsError(try decode(StringModel.self, #"{"amount":"0x10","index":"7"}"#))
        XCTAssertThrowsError(try decode(StringModel.self, #"{"amount":"10","index":"-1"}"#))
    }

    // MARK: OptionStringCodable

    func testOptionStringCodableEncodesNullForNone() throws {
        XCTAssertEqual(try scaleJson(OptionStringModel(value: 12)), #"{"value":"12"}"#)
        XCTAssertEqual(try scaleJson(OptionStringModel(value: nil)), #"{"value":null}"#)
    }

    func testOptionStringCodableDecodesNullAndString() throws {
        XCTAssertEqual(try decode(OptionStringModel.self, #"{"value":"12"}"#).value, 12)
        XCTAssertNil(try decode(OptionStringModel.self, #"{"value":null}"#).value)
        XCTAssertThrowsError(try decode(OptionStringModel.self, #"{"value":"abc"}"#))
    }

    func testMissingKeyHandlingPerWrapper() {
        XCTAssertEqual(describeDecoding(OptionStringModel.self, "{}"), "decoded: OptionStringModel(_value: SubstrateSdk.OptionStringCodable<Swift.UInt32>(wrappedValue: nil))")
        XCTAssertEqual(describeDecoding(NullModel.self, "{}"), "throws: keyNotFound(value)")
        XCTAssertEqual(describeDecoding(BytesModel.self, "{}"), "throws: keyNotFound(value)")
        XCTAssertEqual(describeDecoding(StringModel.self, #"{"amount":"1"}"#), "throws: keyNotFound(index)")
    }

    // MARK: NullCodable

    func testNullCodableEncodesExplicitNull() throws {
        XCTAssertEqual(try scaleJson(NullModel(value: nil)), #"{"value":null}"#)
        XCTAssertEqual(try scaleJson(NullModel(value: "a")), #"{"value":"a"}"#)
        XCTAssertNil(try decode(NullModel.self, #"{"value":null}"#).value)
    }

    // MARK: StringScaleMapper

    func testStringScaleMapperRoundTrip() throws {
        let value = StringScaleMapper(value: BigUInt(123))

        XCTAssertEqual(try scaleJson(value), #""123""#)
        XCTAssertEqual(try decode(StringScaleMapper<BigUInt>.self, #""123""#).value, BigUInt(123))
        XCTAssertThrowsError(try decode(StringScaleMapper<UInt8>.self, #""256""#))
    }

    // MARK: MultiSignature

    func testMultiSignatureEncodesAsTypeAndHexData() throws {
        let data = Data(repeating: 0xAB, count: 4)

        XCTAssertEqual(try scaleJson(MultiSignature.sr25519(data: data)), #"["Sr25519","0xabababab"]"#)
        XCTAssertEqual(try scaleJson(MultiSignature.ed25519(data: data)), #"["Ed25519","0xabababab"]"#)
        XCTAssertEqual(try scaleJson(MultiSignature.ecdsa(data: data)), #"["Ecdsa","0xabababab"]"#)
    }

    func testMultiSignatureDecodesByteArrayRepresentation() throws {
        let signature = try decode(MultiSignature.self, #"["Ed25519",["171","205"]]"#)

        guard case let .ed25519(data) = signature else {
            return XCTFail("Unexpected signature: \(signature)")
        }

        XCTAssertEqual(data, Data([0xAB, 0xCD]))
    }

    func testMultiSignatureRejectsUnknownType() {
        XCTAssertThrowsError(try decode(MultiSignature.self, #"["Bls",["1"]]"#))
    }

    func testMultiSignatureRoundTripsThroughScaleJson() throws {
        let original = MultiSignature.ecdsa(data: ExtrinsicGolden.ecdsaSignature)

        let restored = try original.toScaleCompatibleJSON().map(to: MultiSignature.self)

        guard case let .ecdsa(data) = restored else {
            return XCTFail("Unexpected signature: \(restored)")
        }

        XCTAssertEqual(data, ExtrinsicGolden.ecdsaSignature)
    }
}

private extension SubstrateCodableWrappersCharacterizationTests {
    /// The app never encodes these models with a plain `JSONEncoder`: runtime models always go through
    /// the scale compatible JSON of the SDK (hex `Data`, string numbers), so the tests do the same.
    func scaleJson<T: Encodable>(_ value: T) throws -> String {
        try ExtrinsicGolden.json(value.toScaleCompatibleJSON())
    }

    func decode<T: Decodable>(_: T.Type, _ json: String) throws -> T {
        try ExtrinsicGolden.parseJSON(json).map(to: T.self)
    }

    /// "decoded: <value>" or "throws: <error case>", for behaviour that is easier to pin as text.
    func describeDecoding<T: Decodable>(_ type: T.Type, _ json: String) -> String {
        do {
            return "decoded: \(try decode(type, json))"
        } catch let DecodingError.keyNotFound(key, _) {
            return "throws: keyNotFound(\(key.stringValue))"
        } catch {
            return "throws: \(Swift.type(of: error))"
        }
    }
}
