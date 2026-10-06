@testable import novawallet
import XCTest

final class SubtensorOperationResultViewModelFactoryTests: XCTestCase {
    private let locale = Locale(identifier: "en")
    private let hotkey = Data(repeating: 7, count: 32)

    func testRootUnstakeDoneShowsStakeAfterFromGroupTotalMinusExecutedAndTheAlphaFee() throws {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        let outcome = SubtensorStakingOperationOutcome(
            executed: SubtensorExecutedAmounts(
                tao: 10_000_000_000,
                alpha: 10_000_000_000,
                netuid: SubtensorStakingPallet.rootNetuid
            ),
            novaFeePaid: nil,
            alphaFeePaid: 629_364,
            networkFeePaid: 629_364,
            extrinsicHash: "0x02",
            blockHash: "0x01"
        )

        let viewModel = makeFactory().createViewModel(
            for: .done(outcome: outcome, time: Date()),
            context: SubtensorResultViewContext(
                request: makeRootUnstakeRequest(stakeBefore: 20_000_000_000, amount: 10_000_000_000),
                catalogue: nil,
                subnetLogos: nil,
                remainedTime: 0
            ),
            locale: locale
        )

        guard case let .sheet(sheet) = viewModel else {
            return XCTFail("unexpected view model \(viewModel)")
        }

        XCTAssertEqual(sheet.rows.first?.value, "9.99937 TAO")
        XCTAssertEqual(sheet.message, strings.stakingSubtensorResultRootUnstakedMessageFormat("9.99937 TAO"))
    }

    private func makeFactory() -> SubtensorOperationResultViewModelFactory {
        SubtensorOperationResultViewModelFactory(
            chainAsset: SubtensorFlowChainWorld.chainAsset(),
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())
        )
    }

    private func makeRootUnstakeRequest(stakeBefore: Balance, amount: Balance) -> SubtensorOperationResultRequest {
        SubtensorOperationResultRequest(
            operation: .rootUnstake(hotkey: hotkey, amount: amount),
            origin: .unstake,
            account: SubtensorFlowChainWorld.coldkeyAccount(),
            target: .root,
            payAmount: amount,
            quote: nil,
            slippage: nil,
            validator: SubtensorConfirmValidator(
                hotkey: hotkey,
                display: DisplayAddress(address: "5FNova", username: "Nova Wallet"),
                annualRate: nil
            ),
            estimatedNetworkFee: ExtrinsicFee(amount: 629_364, payer: nil, weight: .init(refTime: 1000, proofSize: 0)),
            stakeBefore: stakeBefore,
            groupHotkeyCount: 1,
            emptiesPosition: false,
            prices: SubtensorOperationResultPrices(taoPrice: nil, alphaSpot: nil),
            costBasis: nil
        )
    }
}
