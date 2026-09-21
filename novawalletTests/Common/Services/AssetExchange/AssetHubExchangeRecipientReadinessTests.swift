import XCTest
@testable import novawallet
import BigInt

final class AssetHubExchangeRecipientReadinessTests: XCTestCase {
    func testNativeRecipientWithProviderAndEnoughFreeReturnsExistentialDeposit() throws {
        let minimum = try AssetHubExchangeRecipientReadiness.nativeMinimumBalance(
            accountInfo: try createAccountInfo(providers: 1, free: 100),
            existentialDeposit: 100
        )

        XCTAssertEqual(minimum, 100)
    }

    func testNativeRecipientWithoutProvidersIsRejected() throws {
        XCTAssertThrowsError(
            try AssetHubExchangeRecipientReadiness.nativeMinimumBalance(
                accountInfo: try createAccountInfo(providers: 0, free: 1000),
                existentialDeposit: 100
            )
        ) { XCTAssertEqual($0 as? AssetHubExchangePreparationError, .recipientUnavailable) }
    }

    func testNativeRecipientBelowExistentialDepositIsRejected() throws {
        XCTAssertThrowsError(
            try AssetHubExchangeRecipientReadiness.nativeMinimumBalance(
                accountInfo: try createAccountInfo(providers: 1, free: 99),
                existentialDeposit: 100
            )
        ) { XCTAssertEqual($0 as? AssetHubExchangePreparationError, .recipientUnavailable) }
    }

    func testMissingNativeAccountIsRejected() {
        XCTAssertThrowsError(
            try AssetHubExchangeRecipientReadiness.nativeMinimumBalance(
                accountInfo: nil,
                existentialDeposit: 100
            )
        ) { XCTAssertEqual($0 as? AssetHubExchangePreparationError, .recipientUnavailable) }
    }

    func testLiquidAssetAccountAtMinBalanceReturnsMinBalance() throws {
        let minimum = try AssetHubExchangeRecipientReadiness.assetsMinimumBalance(
            details: try createDetails(status: "Live", minBalance: 50),
            account: try createAccount(status: "Liquid", balance: 50)
        )

        XCTAssertEqual(minimum, 50)
    }

    func testFrozenAssetAccountCanStillReceive() throws {
        let minimum = try AssetHubExchangeRecipientReadiness.assetsMinimumBalance(
            details: try createDetails(status: "Live", minBalance: 50),
            account: try createAccount(status: "Frozen", balance: 50)
        )

        XCTAssertEqual(minimum, 50)
    }

    func testBlockedAssetAccountIsRejected() throws {
        let details = try createDetails(status: "Live", minBalance: 50)
        let account = try createAccount(status: "Blocked", balance: 1000)

        XCTAssertThrowsError(
            try AssetHubExchangeRecipientReadiness.assetsMinimumBalance(details: details, account: account)
        ) { XCTAssertEqual($0 as? AssetHubExchangePreparationError, .recipientUnavailable) }
    }

    func testDestroyingAssetIsRejected() throws {
        let details = try createDetails(status: "Destroying", minBalance: 50)
        let account = try createAccount(status: "Liquid", balance: 1000)

        XCTAssertThrowsError(
            try AssetHubExchangeRecipientReadiness.assetsMinimumBalance(details: details, account: account)
        ) { XCTAssertEqual($0 as? AssetHubExchangePreparationError, .recipientUnavailable) }
    }

    func testAssetAccountBelowMinBalanceIsRejected() throws {
        let details = try createDetails(status: "Live", minBalance: 50)
        let account = try createAccount(status: "Liquid", balance: 49)

        XCTAssertThrowsError(
            try AssetHubExchangeRecipientReadiness.assetsMinimumBalance(details: details, account: account)
        ) { XCTAssertEqual($0 as? AssetHubExchangePreparationError, .recipientUnavailable) }
    }

    func testMissingAssetAccountIsRejected() throws {
        let details = try createDetails(status: "Live", minBalance: 50)

        XCTAssertThrowsError(
            try AssetHubExchangeRecipientReadiness.assetsMinimumBalance(details: details, account: nil)
        ) { XCTAssertEqual($0 as? AssetHubExchangePreparationError, .recipientUnavailable) }
    }

    func testUnsupportedStorageProducesUnsupportedStorageError() throws {
        let factory = AssetHubExchangeCommissionRecipientFactory(
            connection: TestJSONRPCEngine(),
            runtimeProvider: try RuntimeCodingServiceStub.createWestendService(),
            operationQueue: OperationQueue()
        )

        let wrapper = factory.createMinimumBalanceWrapper(
            recipient: AccountId(repeating: 1, count: 32),
            storageInfo: .evmNative
        )

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        XCTAssertThrowsError(try wrapper.targetOperation.extractNoCancellableResultData()) {
            XCTAssertEqual($0 as? AssetHubExchangePreparationError, .unsupportedStorage)
        }
    }
}

private extension AssetHubExchangeRecipientReadinessTests {
    func createAccountInfo(providers: UInt32, free: BigUInt) throws -> AccountInfo {
        let json = """
        {"nonce":"0","consumers":"0","providers":"\(providers)",
         "data":{"free":"\(free)","reserved":"0","frozen":"0"}}
        """

        return try JSONDecoder().decode(AccountInfo.self, from: Data(json.utf8))
    }

    func createDetails(status: String, minBalance: BigUInt) throws -> PalletAssets.Details {
        let issuer = Array(repeating: "\"1\"", count: 32).joined(separator: ",")

        let json = """
        {"minBalance":"\(minBalance)","status":["\(status)"],"isSufficient":true,"issuer":[\(issuer)]}
        """

        return try JSONDecoder().decode(PalletAssets.Details.self, from: Data(json.utf8))
    }

    func createAccount(status: String, balance: BigUInt) throws -> PalletAssets.Account {
        let json = """
        {"balance":"\(balance)","status":["\(status)"]}
        """

        return try JSONDecoder().decode(PalletAssets.Account.self, from: Data(json.utf8))
    }
}
