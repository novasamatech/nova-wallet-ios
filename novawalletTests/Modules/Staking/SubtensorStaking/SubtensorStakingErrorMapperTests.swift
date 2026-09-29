@testable import novawallet
import SubstrateSdk
import XCTest

final class SubtensorStakingErrorMapperTests: XCTestCase {
    private let mapper = SubtensorStakingErrorMapper()

    private func makeDispatchError(module: String, error: String) -> DispatchCallError {
        .module(
            .init(
                raw: .init(moduleIndex: 7, error: Data([0, 0, 0, 0])),
                display: .init(moduleName: module, errorName: error)
            )
        )
    }

    private func mapModuleError(_ module: String, _ error: String) -> Error {
        mapper.mapSubmission(error: makeDispatchError(module: module, error: error))
    }

    private func makeRpcError(code: Int, data: String) throws -> JSONRPCError {
        let json = "{\"code\": \(code), \"message\": \"Invalid Transaction\", \"data\": \"\(data)\"}"

        return try JSONDecoder().decode(JSONRPCError.self, from: Data(json.utf8))
    }

    func testMapsAmountTooLow() {
        let mapped = mapModuleError("SubtensorModule", "AmountTooLow")

        XCTAssertEqual(mapped as? SubtensorStakingSubmissionError, .amountTooLow)
    }

    func testMapsNotEnoughBalanceToStake() {
        let mapped = mapModuleError("SubtensorModule", "NotEnoughBalanceToStake")

        XCTAssertEqual(mapped as? SubtensorStakingSubmissionError, .notEnoughBalanceToStake)
    }

    func testMapsStakeUnavailable() {
        let mapped = mapModuleError("SubtensorModule", "StakeUnavailable")

        XCTAssertEqual(mapped as? SubtensorStakingSubmissionError, .stakeUnavailable)
    }

    func testMapsSlippageTooHigh() {
        let mapped = mapModuleError("SubtensorModule", "SlippageTooHigh")

        XCTAssertEqual(mapped as? SubtensorStakingSubmissionError, .slippageTooHigh)
    }

    func testMapsHotkeyAccountNotExists() {
        let mapped = mapModuleError("SubtensorModule", "HotKeyAccountNotExists")

        XCTAssertEqual(mapped as? SubtensorStakingSubmissionError, .hotkeyNotRegistered)
    }

    func testMapsColdkeySwapAnnounced() {
        let mapped = mapModuleError("SubtensorModule", "ColdkeySwapAnnounced")

        XCTAssertEqual(mapped as? SubtensorStakingSubmissionError, .coldkeySwapInProgress)
    }

    func testMapsColdkeySwapDisputed() {
        let mapped = mapModuleError("SubtensorModule", "ColdkeySwapDisputed")

        XCTAssertEqual(mapped as? SubtensorStakingSubmissionError, .coldkeySwapInProgress)
    }

    func testMapsRootStakeLocked() {
        let mapped = mapModuleError("SubtensorModule", "RootStakeLocked")

        XCTAssertEqual(mapped as? SubtensorStakingSubmissionError, .rootStakeLocked)
    }

    func testMapsBetaBasketSeedInProgressToTemporarilyUnavailable() {
        let mapped = mapModuleError("SubtensorModule", "BetaBasketSeedInProgress")

        XCTAssertEqual(mapped as? SubtensorStakingSubmissionError, .temporarilyUnavailable)
    }

    func testMapsSubtokenDisabled() {
        let mapped = mapModuleError("SubtensorModule", "SubtokenDisabled")

        XCTAssertEqual(mapped as? SubtensorStakingSubmissionError, .subtokenDisabled)
    }

    func testMapsSubnetNotExists() {
        let mapped = mapModuleError("SubtensorModule", "SubnetNotExists")

        XCTAssertEqual(mapped as? SubtensorStakingSubmissionError, .subnetNotExists)
    }

    func testMapsSwapInsufficientBalanceToNotEnoughBalance() {
        let mapped = mapModuleError("Swap", "InsufficientBalance")

        XCTAssertEqual(mapped as? SubtensorStakingSubmissionError, .notEnoughBalanceToStake)
    }

    func testMapsSwapSubtokenDisabled() {
        let mapped = mapModuleError("Swap", "SubtokenDisabled")

        XCTAssertEqual(mapped as? SubtensorStakingSubmissionError, .subtokenDisabled)
    }

    func testMapsSwapPriceLimitExceeded() {
        let mapped = mapModuleError("Swap", "PriceLimitExceeded")

        XCTAssertEqual(mapped as? SubtensorStakingSubmissionError, .priceLimitExceeded)
    }

    func testMapsSwapInsufficientLiquidity() {
        let mapped = mapModuleError("Swap", "InsufficientLiquidity")

        XCTAssertEqual(mapped as? SubtensorStakingSubmissionError, .insufficientLiquidity)
    }

    func testMapsSystemCallFilteredToSafeMode() {
        let mapped = mapModuleError("System", "CallFiltered")

        XCTAssertEqual(mapped as? SubtensorStakingSubmissionError, .safeModeActive)
    }

    func testUnmappedModuleErrorPassesThrough() {
        let original = makeDispatchError(module: "SubtensorModule", error: "NonAssociatedColdKey")

        let mapped = mapper.mapSubmission(error: original)

        XCTAssertNil(mapped as? SubtensorStakingSubmissionError)
        XCTAssertNotNil(mapped as? DispatchCallError)
    }

    func testUnknownModulePassesThrough() {
        let original = makeDispatchError(module: "Balances", error: "InsufficientBalance")

        let mapped = mapper.mapSubmission(error: original)

        XCTAssertNil(mapped as? SubtensorStakingSubmissionError)
    }

    func testMapsPoolFeeRejection() throws {
        let rpcError = try makeRpcError(code: 1010, data: "Inability to pay some fees , e.g. account balance too low")

        let mapped = mapper.mapSubmission(error: rpcError)

        XCTAssertEqual(mapped as? SubtensorStakingSubmissionError, .feeUnpayable)
    }

    func testPoolRejectionWithOtherDataPassesThrough() throws {
        let rpcError = try makeRpcError(code: 1010, data: "Transaction is outdated")

        let mapped = mapper.mapSubmission(error: rpcError)

        XCTAssertNil(mapped as? SubtensorStakingSubmissionError)
        XCTAssertNotNil(mapped as? JSONRPCError)
    }

    func testMapsNotEnoughStakeToWithdraw() {
        let mapped = mapModuleError("SubtensorModule", "NotEnoughStakeToWithdraw")

        XCTAssertEqual(mapped as? SubtensorStakingSubmissionError, .notEnoughStakeToWithdraw)
    }

    func testMapsTooManyStakingHotkeys() {
        let mapped = mapModuleError("SubtensorModule", "TooManyStakingHotkeys")

        XCTAssertEqual(mapped as? SubtensorStakingSubmissionError, .tooManyStakingHotkeys)
    }

    func testMapsInsufficientTaoBalanceToNotEnoughBalance() {
        let mapped = mapModuleError("SubtensorModule", "InsufficientTaoBalance")

        XCTAssertEqual(mapped as? SubtensorStakingSubmissionError, .notEnoughBalanceToStake)
    }

    func testMapsBasketDepositPendingToTemporarilyUnavailable() {
        let mapped = mapModuleError("SubtensorModule", "BasketDepositPending")

        XCTAssertEqual(mapped as? SubtensorStakingSubmissionError, .temporarilyUnavailable)
    }

    func testMapsPoolColdkeySwapAnnouncedCustomCode() throws {
        let rpcError = try makeRpcError(code: 1010, data: "Custom error: 0")

        let mapped = mapper.mapSubmission(error: rpcError)

        XCTAssertEqual(mapped as? SubtensorStakingSubmissionError, .coldkeySwapInProgress)
    }

    func testMapsPoolColdkeySwapDisputedCustomCode() throws {
        let rpcError = try makeRpcError(code: 1010, data: "Custom error: 21")

        let mapped = mapper.mapSubmission(error: rpcError)

        XCTAssertEqual(mapped as? SubtensorStakingSubmissionError, .coldkeySwapInProgress)
    }

    func testPoolRejectionWithOtherCustomCodePassesThrough() throws {
        let rpcError = try makeRpcError(code: 1010, data: "Custom error: 210")

        let mapped = mapper.mapSubmission(error: rpcError)

        XCTAssertNil(mapped as? SubtensorStakingSubmissionError)
        XCTAssertNotNil(mapped as? JSONRPCError)
    }

    func testMapsTokenBalanceErrorsOfTheFeeTransferToNotEnoughBalance() {
        let reasons = ["FundsUnavailable", "NotExpendable", "Frozen", "BelowMinimum"]

        let mapped = reasons.map { reason in
            mapper.mapSubmission(
                error: DispatchCallError.other(.init(module: "Token", reason: reason))
            ) as? SubtensorStakingSubmissionError
        }

        XCTAssertEqual(mapped, Array(repeating: .notEnoughBalanceToStake, count: reasons.count))
    }

    func testOtherTokenErrorPassesThrough() {
        let original = DispatchCallError.other(.init(module: "Token", reason: "CannotCreate"))

        let mapped = mapper.mapSubmission(error: original)

        XCTAssertNil(mapped as? SubtensorStakingSubmissionError)
        XCTAssertNotNil(mapped as? DispatchCallError)
    }

    func testSafeModeContentUsesChainWideMessage() {
        let content = SubtensorStakingSubmissionError.safeModeActive.toErrorContent(for: locale())

        XCTAssertEqual(
            content.message,
            R.string(preferredLanguages: locale().rLanguages).localizable.stakingSubtensorSafeModeMessage()
        )
    }

    private func locale() -> Locale {
        Locale(identifier: "en")
    }
}
