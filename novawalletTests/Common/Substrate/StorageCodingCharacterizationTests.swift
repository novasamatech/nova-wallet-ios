import BigInt
@testable import novawallet
import Operation_iOS
import SubstrateSdk
import XCTest

/// Pins storage key construction and storage value decoding, the read path of every balance and state query.
/// Golden values were recorded on substrate-sdk-ios 4.5.2 against the Westend v14 fixture.
final class StorageCodingCharacterizationTests: XCTestCase {
    /// `AccountInfo { nonce: 5, consumers: 1, providers: 1, sufficients: 0, data: { free: 10^13, reserved: 0,
    /// misc_frozen: 100, fee_frozen: 0 } }` as System.Account stores it at this runtime.
    private static let accountInfoHex = "0x05000000" + "01000000" + "01000000" + "00000000" +
        "00a0724e180900000000000000000000" + "00000000000000000000000000000000" +
        "64000000000000000000000000000000" + "00000000000000000000000000000000"

    private let operationQueue = OperationQueue()
    private let keyFactory = StorageKeyFactory()

    private var runtime: ExtrinsicGoldenRuntime!

    override func setUpWithError() throws {
        runtime = try ExtrinsicGoldenRuntime.westend()
    }

    // MARK: Keys

    func testPlainAndAccountKeys() throws {
        XCTAssertEqual(try keyFactory.key(from: SystemPallet.eventsPath).toHex(includePrefix: true), "0x26aa394eea5630e07c48ae0c9558cef780d41e5e16056765bc8461851072c9d7")
        XCTAssertEqual(try keyFactory.totalIssuance().toHex(includePrefix: true), "0xc2261276cc9d1f8598ea4b6a74b15c2f57c875e4cff74148e4628f264b974c80")
        XCTAssertEqual(try keyFactory.accountInfoKeyForId(ExtrinsicGolden.senderId).toHex(includePrefix: true), "0x26aa394eea5630e07c48ae0c9558cef7b99d880ec681799c0cf30e8886371da97f9c299f1d9bbe856fbf2c98f0f914351111111111111111111111111111111111111111111111111111111111111111")
    }

    func testKeyPerHasher() throws {
        let hashers: [StorageHasher] = [.blake128, .blake256, .blake128Concat, .twox128, .twox256, .twox64Concat, .identity]

        let keys = try hashers.map { hasher in
            try keyFactory.createStorageKey(
                moduleName: "Test",
                storageName: "Item",
                key: Data([1, 2, 3, 4]),
                hasher: hasher
            )
            .toHex()
        }

        XCTAssertEqual(keys.joined(separator: ";"), "b422898ac3ef83da3f78bdf77b08a216e6636c7091b616c035068763633f33e250f21536142cf23a3e3e25f01ef8d5ea;b422898ac3ef83da3f78bdf77b08a216e6636c7091b616c035068763633f33e228517e4cdf6c90798c1a983b03727ca7743c21a3880672429ccfc5bd15ea5f72;b422898ac3ef83da3f78bdf77b08a216e6636c7091b616c035068763633f33e250f21536142cf23a3e3e25f01ef8d5ea01020304;b422898ac3ef83da3f78bdf77b08a216e6636c7091b616c035068763633f33e2d12ea9a2e32026548ca7941f0915f3b5;b422898ac3ef83da3f78bdf77b08a216e6636c7091b616c035068763633f33e2d12ea9a2e32026548ca7941f0915f3b5c57be935824e6c670cd8933cbdce1266;b422898ac3ef83da3f78bdf77b08a216e6636c7091b616c035068763633f33e2d12ea9a2e320265401020304;b422898ac3ef83da3f78bdf77b08a216e6636c7091b616c035068763633f33e201020304")
    }

    func testMapKeyEncodingOperationMatchesKeyFactory() throws {
        let operation = MapKeyEncodingOperation<BytesCodable>(
            path: SystemPallet.accountPath,
            storageKeyFactory: keyFactory,
            keyParams: [BytesCodable(wrappedValue: ExtrinsicGolden.senderId)]
        )
        operation.codingFactory = runtime.codingFactory

        operationQueue.addOperations([operation], waitUntilFinished: true)

        XCTAssertEqual(
            try operation.extractNoCancellableResultData(),
            [try keyFactory.accountInfoKeyForId(ExtrinsicGolden.senderId)]
        )
    }

    func testUnkeyedEncodingOperationValidatesStoragePath() throws {
        let valid = UnkeyedEncodingOperation(path: SystemPallet.eventsPath, storageKeyFactory: keyFactory)
        let invalid = UnkeyedEncodingOperation(
            path: StorageCodingPath(moduleName: "System", itemName: "NoSuchItem"),
            storageKeyFactory: keyFactory
        )
        valid.codingFactory = runtime.codingFactory
        invalid.codingFactory = runtime.codingFactory

        operationQueue.addOperations([valid, invalid], waitUntilFinished: true)

        XCTAssertEqual(try valid.extractNoCancellableResultData(), try keyFactory.key(from: SystemPallet.eventsPath))
        XCTAssertThrowsError(try invalid.extractNoCancellableResultData()) { error in
            XCTAssertEqual(error as? StorageKeyEncodingOperationError, .invalidStoragePath)
        }
    }

    // MARK: Values

    func testAccountInfoDecoding() throws {
        let operation = StorageDecodingOperation<AccountInfo>(
            path: SystemPallet.accountPath,
            data: try Data(hexString: Self.accountInfoHex)
        )
        operation.codingFactory = runtime.codingFactory

        operationQueue.addOperations([operation], waitUntilFinished: true)
        let accountInfo = try operation.extractNoCancellableResultData()

        XCTAssertEqual(accountInfo.nonce, 5)
        XCTAssertEqual(accountInfo.consumers, 1)
        XCTAssertEqual(accountInfo.providers, 1)
        XCTAssertEqual(accountInfo.sufficients, 0)
        XCTAssertEqual(accountInfo.data.free, BigUInt(10_000_000_000_000))
        XCTAssertEqual(accountInfo.data.reserved, 0)
        XCTAssertEqual(accountInfo.data.miscFrozen, 100)
        XCTAssertEqual(accountInfo.data.feeFrozen, 0)
        XCTAssertNil(accountInfo.data.frozen)
        XCTAssertNil(accountInfo.data.flags)
        XCTAssertEqual(accountInfo.data.available, BigUInt(9_999_999_999_900))
    }

    func testAccountInfoJsonShape() throws {
        let operation = StorageJSONDecodingOperation(
            path: SystemPallet.accountPath,
            data: try Data(hexString: Self.accountInfoHex)
        )
        operation.codingFactory = runtime.codingFactory

        operationQueue.addOperations([operation], waitUntilFinished: true)

        XCTAssertEqual(try ExtrinsicGolden.json(operation.extractNoCancellableResultData()), #"{"consumers":"1","data":{"feeFrozen":"0","free":"10000000000000","miscFrozen":"100","reserved":"0"},"nonce":"5","providers":"1","sufficients":"0"}"#)
    }

    func testFallbackDecodingUsesStorageDefaultWhenValueIsMissing() throws {
        let withDefault = StorageFallbackDecodingOperation<AccountInfo>(path: SystemPallet.accountPath)
        let optional = StorageFallbackDecodingOperation<StringScaleMapper<UInt32>>(
            path: StorageCodingPath(moduleName: "Staking", itemName: "CurrentEra")
        )
        withDefault.codingFactory = runtime.codingFactory
        optional.codingFactory = runtime.codingFactory

        operationQueue.addOperations([withDefault, optional], waitUntilFinished: true)
        let accountInfo = try XCTUnwrap(withDefault.extractNoCancellableResultData())

        XCTAssertEqual(accountInfo.nonce, 0)
        XCTAssertEqual(accountInfo.data.free, 0)
        XCTAssertNil(try optional.extractNoCancellableResultData())
    }

    func testDecodingWithoutCodingFactoryFails() {
        let operation = StorageDecodingOperation<AccountInfo>(path: SystemPallet.accountPath, data: Data([0]))

        operationQueue.addOperations([operation], waitUntilFinished: true)

        XCTAssertThrowsError(try operation.extractNoCancellableResultData()) { error in
            XCTAssertEqual(error as? StorageDecodingOperationError, .missingRequiredParams)
        }
    }
}
