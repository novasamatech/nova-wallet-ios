import BigInt
@testable import novawallet
import XCTest

final class SubtensorQuoteViewModelFactoryTests: XCTestCase {
    private let locale = Locale(identifier: "en")

    private let buySim = SubtensorStakingPallet.SimSwapResult(
        taoAmount: 999_496_453,
        alphaAmount: 130_082_405_209,
        taoFee: 503_547,
        alphaFee: 0,
        taoSlippage: 0,
        alphaSlippage: 70_762_340
    )

    private let sellSim = SubtensorStakingPallet.SimSwapResult(
        taoAmount: 998_912_946,
        alphaAmount: 130_016_902_511,
        taoFee: 0,
        alphaFee: 65_502_698,
        taoSlippage: 543_368,
        alphaSlippage: 0
    )

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
        SubtensorQuoteViewModelFactory(chainAsset: makeChainAsset())
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

    private func makeStakeQuote() -> SubtensorQuote {
        SubtensorQuote(
            args: SubtensorQuoteArgs(netuid: 1, direction: .stake(taoIn: 1_000_000_000)),
            sim: buySim,
            spotPrice: 7_683_255,
            feeRate: 33
        )
    }

    private func makeUnstakeQuote() -> SubtensorQuote {
        SubtensorQuote(
            args: SubtensorQuoteArgs(netuid: 1, direction: .unstake(alphaIn: 130_082_405_209)),
            sim: sellSim,
            spotPrice: 7_683_255,
            feeRate: 33
        )
    }

    func testStakePanelDenominatesReceiveInAlphaAndFeeInTao() throws {
        let panel = try XCTUnwrap(
            makeFactory().createQuotePanel(
                for: makeStakeQuote(),
                target: makeSubnetTarget(),
                locale: locale
            )
        )

        XCTAssertTrue(panel.receive.hasPrefix("~"))
        XCTAssertTrue(panel.receive.hasSuffix("α"))
        XCTAssertFalse(panel.receive.contains("TAO"))
        XCTAssertTrue(panel.poolFee.contains("TAO"))
        XCTAssertFalse(panel.poolFee.contains("α"))
    }

    func testUnstakePanelDenominatesReceiveInTaoAndFeeInAlpha() throws {
        let panel = try XCTUnwrap(
            makeFactory().createQuotePanel(
                for: makeUnstakeQuote(),
                target: makeSubnetTarget(),
                locale: locale
            )
        )

        XCTAssertTrue(panel.receive.hasPrefix("~"))
        XCTAssertTrue(panel.receive.hasSuffix("TAO"))
        XCTAssertTrue(panel.poolFee.contains("α"))
        XCTAssertFalse(panel.poolFee.contains("TAO"))
    }

    func testPoolFeeCarriesLiveFeeRatePercent() throws {
        let panel = try XCTUnwrap(
            makeFactory().createQuotePanel(
                for: makeStakeQuote(),
                target: makeSubnetTarget(),
                locale: locale
            )
        )

        XCTAssertTrue(panel.poolFee.hasSuffix("(0.05%)"))
    }

    func testRootTargetProducesNoQuotePanel() {
        XCTAssertNil(
            makeFactory().createQuotePanel(
                for: makeStakeQuote(),
                target: .root,
                locale: locale
            )
        )
    }

    func testMissingQuoteProducesNoQuotePanel() {
        XCTAssertNil(
            makeFactory().createQuotePanel(
                for: nil,
                target: makeSubnetTarget(),
                locale: locale
            )
        )
    }

    func testPinnedCaptureImpactRendersBelowWarningThreshold() throws {
        let panel = try XCTUnwrap(
            makeFactory().createQuotePanel(
                for: makeStakeQuote(),
                target: makeSubnetTarget(),
                locale: locale
            )
        )

        XCTAssertFalse(panel.isImpactHigh)
    }
}
