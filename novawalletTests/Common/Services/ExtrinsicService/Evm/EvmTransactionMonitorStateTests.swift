import BigInt
@testable import novawallet
import SubstrateSdk
import XCTest

final class EvmTransactionMonitorStateTests: XCTestCase {
    private let nonce: BigUInt = 7
    private let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
    private let txHash = "0x5f7c0b5bbc2a3e2d7e4f6a1b9c8d7e6f5a4b3c2d1e0f9a8b7c6d5e4f3a2b1c0d"
    private let blockHash = "0x1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b"
    private let timing = EvmTransactionMonitorTiming(
        pollInterval: 4,
        waitBudget: 120,
        droppedWindow: 36,
        minHeadCheckSpacing: 2
    )

    func testReceiptWithStatusOneIsSuccess() {
        var state = makeState()

        let decision = state.decide(on: .receipt(makeReceipt(status: "0x1")), at: time(4))

        XCTAssertEqual(decision, .success(transactionHash: txHash, blockHash: blockHash))
    }

    func testReceiptWithStatusZeroIsFailure() {
        var state = makeState()

        let decision = state.decide(on: .receipt(makeReceipt(status: "0x0")), at: time(4))

        XCTAssertEqual(decision, .failure(transactionHash: txHash))
    }

    func testReceiptWithoutStatusIsSuccess() {
        var state = makeState()

        let decision = state.decide(on: .receipt(makeReceipt(status: nil)), at: time(4))

        XCTAssertEqual(decision, .success(transactionHash: txHash, blockHash: blockHash))
    }

    func testReceiptWinsOverConsumedNonce() {
        var state = makeState()
        _ = decideConsumed(&state, at: [4, 8, 12, 16, 20, 24, 28, 32, 36])

        let decision = state.decide(on: .receipt(makeReceipt(status: "0x1")), at: time(40))

        XCTAssertEqual(decision, .success(transactionHash: txHash, blockHash: blockHash))
    }

    func testConsumedNonceVerifiesOnlyAfterFourChecksAndWindow() {
        var fastChecksState = makeState()
        var slowChecksState = makeState()

        let fastChecks = decideConsumed(&fastChecksState, at: [4, 8, 12, 16, 40])
        let slowChecks = decideConsumed(&slowChecksState, at: [4, 40, 44, 48])

        XCTAssertEqual(fastChecks, [.wait, .wait, .wait, .wait, .verifyDropped])
        XCTAssertEqual(slowChecks, [.wait, .wait, .wait, .verifyDropped])
    }

    func testNonceNotConsumedResetsStreak() {
        var state = makeState()
        _ = decideConsumed(&state, at: [4, 8, 12, 16])
        _ = state.decide(on: .noReceipt(latestNonce: nonce), at: time(20))

        let decisions = decideConsumed(&state, at: [24, 28, 32, 36, 40, 44, 60])

        XCTAssertEqual(decisions, [.wait, .wait, .wait, .wait, .wait, .wait, .verifyDropped])
    }

    func testUnavailableCheckKeepsStreak() {
        var state = makeState()
        _ = decideConsumed(&state, at: [4, 8])

        let unavailable = [12, 16, 20, 24, 28, 32, 36, 40].map { state.decide(on: .unavailable, at: time($0)) }
        let consumed = decideConsumed(&state, at: [44, 48])

        XCTAssertEqual(unavailable, Array(repeating: .wait, count: 8))
        XCTAssertEqual(consumed, [.wait, .verifyDropped])
    }

    func testVerificationWithoutReceiptIsDropped() {
        XCTAssertEqual(makeState().decideVerification(.success(nil)), .dropped)
    }

    func testBudgetEndsAsStillPending() {
        var state = makeState()

        let decision = state.decide(on: .noReceipt(latestNonce: nonce), at: time(120))

        XCTAssertEqual(decision, .stillPending)
    }

    func testTimingFallsBackToTwelveSecondBlocks() {
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0, isEthereumBased: true)

        let timing = EvmTransactionMonitorTiming(chain: chain)

        XCTAssertEqual(timing.pollInterval, 4)
        XCTAssertEqual(timing.waitBudget, 120)
        XCTAssertEqual(timing.droppedWindow, 36)
        XCTAssertEqual(timing.minHeadCheckSpacing, 2)
    }

    func testAlreadyKnownIsNotDefinitive() throws {
        XCTAssertFalse(try decodeError(message: "already known").isDefinitiveEvmSendRejection)
    }

    func testReplacementUnderpricedIsNotDefinitive() throws {
        XCTAssertFalse(try decodeError(message: "replacement transaction underpriced").isDefinitiveEvmSendRejection)
    }

    func testInsufficientFundsIsDefinitive() throws {
        let message = "insufficient funds for gas * price + value: balance 0, tx cost 21000"

        XCTAssertTrue(try decodeError(message: message).isDefinitiveEvmSendRejection)
    }

    func testUnknownMessageIsNotDefinitive() throws {
        XCTAssertFalse(try decodeError(message: "request timed out upstream").isDefinitiveEvmSendRejection)
    }
}

private extension EvmTransactionMonitorStateTests {
    func makeState() -> EvmTransactionMonitorState {
        EvmTransactionMonitorState(nonce: nonce, timing: timing, startedAt: startedAt)
    }

    func makeReceipt(status: String?) -> EthereumTransactionReceipt {
        EthereumTransactionReceipt(
            blockHash: blockHash,
            transactionHash: txHash,
            effectiveGasPrice: "0x3b9aca00",
            gasUsed: "0x5208",
            status: status
        )
    }

    func time(_ seconds: TimeInterval) -> Date {
        startedAt.addingTimeInterval(seconds)
    }

    func decideConsumed(
        _ state: inout EvmTransactionMonitorState,
        at seconds: [TimeInterval]
    ) -> [EvmTransactionMonitorState.Decision] {
        seconds.map { state.decide(on: .noReceipt(latestNonce: nonce + 1), at: time($0)) }
    }

    func decodeError(message: String) throws -> JSONRPCError {
        try JSONDecoder().decode(JSONRPCError.self, from: Data("{\"code\":-32000,\"message\":\"\(message)\"}".utf8))
    }
}
