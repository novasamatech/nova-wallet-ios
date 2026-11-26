import BigInt
@testable import novawallet
import SubstrateSdk
import XCTest

final class EvmFeeModelTests: XCTestCase {
    private let baseFee: BigUInt = 106_500_000
    private let gasLimit: BigUInt = 21000

    func testNovaPricingRaisesNodeTipToFloor() {
        let price = EvmEip1559Fee.nova(baseFee: baseFee, nodeTip: 6232)

        XCTAssertEqual(price.fees.maxPriorityFeePerGas, 1_000_000)
        XCTAssertEqual(price.fees.maxFeePerGas, 2 * baseFee + 1_000_000)
        XCTAssertEqual(price.expectedGasPrice, baseFee + 1_000_000)
    }

    func testNovaPricingKeepsNodeTipAboveFloor() {
        let price = EvmEip1559Fee.nova(baseFee: baseFee, nodeTip: 2_000_000_000)

        XCTAssertEqual(price.fees.maxPriorityFeePerGas, 2_000_000_000)
        XCTAssertEqual(price.fees.maxFeePerGas, 2 * baseFee + 2_000_000_000)
    }

    func testNovaFeeShowsExpectedPriceAndReservesMaxFee() {
        let price = EvmEip1559Fee.nova(baseFee: baseFee, nodeTip: 6232)
        let model = EvmFeeModel(gasLimit: gasLimit, defaultGasPrice: 38, eip1559: price)

        guard case let .eip1559(fees) = model.transactionPrice.pricing else {
            return XCTFail("Expected eip-1559 pricing")
        }

        XCTAssertEqual(model.fee, (baseFee + 1_000_000) * gasLimit)
        XCTAssertEqual(model.reserve, (2 * baseFee + 1_000_000) * gasLimit)
        XCTAssertEqual(fees.maxFeePerGas, price.fees.maxFeePerGas)
        XCTAssertEqual(model.transactionPrice.gasLimit, gasLimit)
    }

    func testLegacyFeeReservesWhatItShows() {
        let model = EvmFeeModel(gasLimit: gasLimit, defaultGasPrice: 20_000_000_000, eip1559: nil)

        guard case let .legacy(gasPrice) = model.transactionPrice.pricing else {
            return XCTFail("Expected legacy pricing")
        }

        XCTAssertEqual(model.reserve, model.fee)
        XCTAssertEqual(gasPrice, 20_000_000_000)
    }

    func testForcingLegacyPricesAtExpectedGasPrice() {
        let price = EvmEip1559Fee.nova(baseFee: baseFee, nodeTip: 6232)
        let model = EvmFeeModel(gasLimit: gasLimit, defaultGasPrice: 38, eip1559: price).forcingLegacy()

        guard case let .legacy(gasPrice) = model.transactionPrice.pricing else {
            return XCTFail("Expected legacy pricing")
        }

        XCTAssertEqual(gasPrice, price.expectedGasPrice)
        XCTAssertEqual(model.reserve, price.expectedGasPrice * gasLimit)
    }

    func testLegacyTxTypeForcesLegacyTransactions() throws {
        let additional = try JSONDecoder().decode(JSON.self, from: Data(#"{"evm":{"txType":"legacy"}}"#.utf8))

        let forcedChain = ChainModelGenerator.generateChain(assets: [], addressPrefix: 1, additional: additional)
        let defaultChain = ChainModelGenerator.generateChain(assets: [], addressPrefix: 1)

        XCTAssertTrue(forcedChain.forcesLegacyEvmTransactions)
        XCTAssertFalse(defaultChain.forcesLegacyEvmTransactions)
    }
}
