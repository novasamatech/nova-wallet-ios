import XCTest
@testable import novawallet

final class HydrationSwapAccountsFilterTests: XCTestCase {
    private let filter = HydrationSwapAccountsFilter()

    // HydraConstants.novaFeeAccountId in the two encodings the history pipeline produces
    private let feeAccountHex = "035ff76d86ca67ef0499f8597101aab0e6ad894a805cd93a51409bd6d71a8841"
    private let feeAccountSS58 = "15ReoCRFgpGXjuaFXzGv7qaqiRrFE5uEMGVC7tBQhaWfzXh"

    // HydraConstants.hydraRouterAccountId ("modlrouterex" + zero padding)
    private let routerAccountHex = "6d6f646c726f7574657265780000000000000000000000000000000000000000"

    private let aliceHex = "1111111111111111111111111111111111111111111111111111111111111111"
    private let bobHex = "2222222222222222222222222222222222222222222222222222222222222222"

    func testHidesTransferToFeeAccountByHexAddress() {
        let item = makeTransfer(sender: aliceHex, receiver: feeAccountHex)
        XCTAssertFalse(filter.shouldDisplayOperation(model: item))
    }

    func testHidesTransferToFeeAccountBySS58Address() {
        let item = makeTransfer(sender: aliceHex, receiver: feeAccountSS58)
        XCTAssertFalse(filter.shouldDisplayOperation(model: item))
    }

    func testHidesTransferToRouterAccount() {
        let item = makeTransfer(sender: aliceHex, receiver: routerAccountHex)
        XCTAssertFalse(filter.shouldDisplayOperation(model: item))
    }

    func testHidesTransferFromRouterAccount() {
        let item = makeTransfer(sender: routerAccountHex, receiver: aliceHex)
        XCTAssertFalse(filter.shouldDisplayOperation(model: item))
    }

    func testKeepsRegularTransferBetweenUsers() {
        let item = makeTransfer(sender: aliceHex, receiver: bobHex)
        XCTAssertTrue(filter.shouldDisplayOperation(model: item))
    }

    func testKeepsTransferWithNilReceiver() {
        let item = makeItem(
            sender: aliceHex,
            receiver: nil,
            callPath: .tokensTransfer
        )
        XCTAssertTrue(filter.shouldDisplayOperation(model: item))
    }

    func testKeepsNonTransferCallInvolvingRouter() {
        let item = makeItem(
            sender: routerAccountHex,
            receiver: aliceHex,
            callPath: CallCodingPath(moduleName: "Router", callName: "sell")
        )
        XCTAssertTrue(filter.shouldDisplayOperation(model: item))
    }

    private func makeTransfer(sender: String, receiver: String) -> TransactionHistoryItem {
        makeItem(sender: sender, receiver: receiver, callPath: .tokensTransfer)
    }

    private func makeItem(
        sender: String,
        receiver: String?,
        callPath: CallCodingPath
    ) -> TransactionHistoryItem {
        TransactionHistoryItem(
            identifier: "test-identifier",
            source: .substrate,
            chainId: KnowChainId.hydra,
            assetId: 0,
            sender: sender,
            receiver: receiver,
            amountInPlank: "1000000",
            status: .success,
            txHash: "0xdeadbeef",
            timestamp: 0,
            fee: nil,
            feeAssetId: nil,
            blockNumber: 100,
            txIndex: 0,
            callPath: callPath,
            call: nil,
            swap: nil
        )
    }
}
