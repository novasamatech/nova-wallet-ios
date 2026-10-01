import BigInt
@testable import novawallet
import XCTest

final class SubtensorQuoteViewModelFactoryTests: XCTestCase {
    private let locale = Locale(identifier: "en")

    private func makeChainAsset() -> ChainAsset {
        let asset = AssetModel(
            assetId: AssetModel.utilityAssetId,
            icon: nil,
            name: "Bittensor",
            symbol: "TAO",
            precision: 9,
            priceId: nil,
            stakings: [.subtensor],
            type: nil,
            typeExtras: nil,
            buyProviders: nil,
            sellProviders: nil,
            source: .remote
        )

        let chain = ChainModelGenerator.generateChain(
            assets: [asset],
            defaultChainId: KnowChainId.bittensor,
            addressPrefix: 42
        )

        return ChainAsset(chain: chain, asset: asset)
    }

    private func makeFactory() -> SubtensorQuoteViewModelFactory {
        SubtensorQuoteViewModelFactory(
            chainAsset: makeChainAsset(),
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())
        )
    }

    private func makeSubnetTarget(netuid: UInt16 = 1) -> SubtensorStakeTarget {
        .subnet(
            info: SubtensorStakingPallet.DynamicInfo(
                netuid: netuid,
                ownerHotkey: Data(repeating: 0, count: 32),
                ownerColdkey: Data(repeating: 0, count: 32),
                subnetName: Data("Apex".utf8),
                tokenSymbol: Data("α".utf8),
                tempo: 99,
                lastStep: 0,
                blocksSinceLastStep: 0,
                emission: 0,
                alphaIn: 0,
                alphaOut: 0,
                taoIn: 0,
                alphaOutEmission: 0,
                alphaInEmission: 0,
                taoInEmission: 0,
                pendingAlphaEmission: 0,
                pendingRootEmission: 0,
                subnetVolume: 0,
                networkRegisteredAt: 0,
                subnetIdentity: nil,
                movingPrice: .null
            ),
            price: 7_683_255
        )
    }

    private func makeBuyTradeQuote() -> SubtensorTradeQuote {
        SubtensorTradeQuote(
            quote: SubtensorQuote(
                args: SubtensorQuoteArgs(netuid: 1, direction: .stake(taoIn: 4_957_858_206)),
                sim: SubtensorStakingPallet.SimSwapResult(
                    taoAmount: 4_957_858_206,
                    alphaAmount: 67_500_000_000,
                    taoFee: 2_496_518,
                    alphaFee: 0,
                    taoSlippage: 0,
                    alphaSlippage: 1_359_000_000
                ),
                spotPrice: 72_000_000,
                feeRate: 33
            ),
            amountIn: 5_000_000_000,
            novaFee: SubtensorNovaFee(amount: 42_141_794, beneficiary: Data(repeating: 0xA4, count: 32)),
            expectedOut: 67_500_000_000,
            swapMinimumOut: 65_580_135_000,
            minimumOut: 65_580_135_000,
            limitPrice: 75_600_000
        )
    }

    private func makeTaoPrice() -> PriceData {
        PriceData(identifier: "bittensor", price: "25", dayChange: nil, currencyId: nil)
    }

    func testBuyTradePanelShowsTheQuotedAlphaItsFiatValueTheSwapRateAndTheMonthlyEarnings() throws {
        let panel = try XCTUnwrap(
            makeFactory().createTradePanel(
                for: makeBuyTradeQuote(),
                amountIn: 5_000_000_000,
                direction: .buy,
                target: makeSubnetTarget(),
                annualRate: Decimal(string: "0.24"),
                taoPrice: makeTaoPrice(),
                locale: locale
            )
        )

        XCTAssertEqual(panel.receive?.amount, "≈ 67.5 α")
        XCTAssertEqual(panel.receive?.price, "$121.5")
        XCTAssertEqual(panel.swapRate, "1 TAO ≈ 13.5 α")
        XCTAssertEqual(panel.earnPerMonth?.amount, "≈ 1.35 α")
        XCTAssertEqual(panel.earnPerMonth?.price, "≈ $2.43")
    }

    func testTradePanelForAnotherAmountShowsOnlyTheSwapRate() throws {
        let panel = try XCTUnwrap(
            makeFactory().createTradePanel(
                for: makeBuyTradeQuote(),
                amountIn: 4_000_000_000,
                direction: .buy,
                target: makeSubnetTarget(),
                annualRate: Decimal(string: "0.24"),
                taoPrice: makeTaoPrice(),
                locale: locale
            )
        )

        XCTAssertNil(panel.receive)
        XCTAssertNil(panel.earnPerMonth)
        XCTAssertEqual(panel.swapRate, "1 TAO ≈ 13.5 α")
    }

    func testNovaFeeDisclosureNamesTheFeePercent() {
        XCTAssertEqual(makeFactory().novaFeeDisclosure(locale: locale), "Includes 0.85% Nova Wallet fee.")
    }
}
