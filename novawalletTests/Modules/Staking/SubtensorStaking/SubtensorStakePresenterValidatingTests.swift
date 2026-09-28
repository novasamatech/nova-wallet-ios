import XCTest
import Cuckoo
import BigInt
@testable import novawallet

final class SubtensorStakePresenterValidatingTests: XCTestCase {
    private struct ValidatingFixture: SubtensorStakePresenterValidating {}

    private final class RuleRecorder {
        var names: [String] = []

        func rule(_ name: String) -> DataValidating {
            ErrorConditionViolation(onError: {}, preservesCondition: { [weak self] in
                self?.names.append(name)
                return true
            })
        }
    }

    private let locale = Locale(identifier: "en")
    private let beneficiary = Data(repeating: 0xBB, count: 32)

    private func makeRecordingFactory(_ recorder: RuleRecorder) -> MockSubtensorStakingValidationFactoryProtocol {
        let factory = MockSubtensorStakingValidationFactoryProtocol()

        stub(factory) { stub in
            when(stub.has(fee: any(), locale: any(), onError: any())).thenReturn(recorder.rule("fee"))
            when(stub.hasPreflight(any(), locale: any(), onRetry: any())).thenReturn(recorder.rule("preflight"))
            when(stub.subnetTradesAvailable(tradesUnavailable: any(), locale: any()))
                .thenReturn(recorder.rule("tradesAvailable"))
            when(stub.hasFreshQuote(any(), locale: any(), onRetry: any())).thenReturn(recorder.rule("freshQuote"))
            when(stub.orderWithinSlippageTolerance(quote: any(), limitPrice: any(), locale: any()))
                .thenReturn(recorder.rule("tolerance"))
            when(stub.canSpendAmount(balance: any(), spendingAmount: any(), locale: any()))
                .thenReturn(recorder.rule("spend"))
            when(
                stub.canPayFeeSpendingAmount(
                    balance: any(),
                    fee: any(),
                    spendingAmount: any(),
                    asset: any(),
                    locale: any()
                )
            ).thenReturn(recorder.rule("feeSpend"))
            when(stub.respectsFeeReserve(amount: any(), transferable: any(), networkFee: any(), locale: any()))
                .thenReturn(recorder.rule("reserve"))
            when(
                stub.hasMinStakeAmount(
                    stakedAmount: any(),
                    minStake: any(),
                    quotedSwapFee: any(),
                    includesNovaFee: any(),
                    locale: any()
                )
            ).thenReturn(recorder.rule("minStake"))
            when(stub.hotkeyIsRegistered(hotkeyExists: any(), locale: any())).thenReturn(recorder.rule("hotkey"))
            when(
                stub.subnetStakingEnabled(
                    netuid: any(),
                    subnetExists: any(),
                    subtokenEnabled: any(),
                    locale: any()
                )
            ).thenReturn(recorder.rule("subnetEnabled"))
            when(
                stub.rootUnlockIntervalElapsed(
                    currentBlock: any(),
                    lastStakeBlock: any(),
                    unlockInterval: any(),
                    blockTime: any(),
                    locale: any()
                )
            ).thenReturn(recorder.rule("rootHold"))
            when(stub.noColdkeySwapInProgress(hasAnnouncement: any(), locale: any()))
                .thenReturn(recorder.rule("coldkeySwap"))
            when(stub.safeModeInactive(safeModeActive: any(), locale: any())).thenReturn(recorder.rule("safeMode"))
            when(stub.priceImpactAcceptable(quote: any(), locale: any())).thenReturn(recorder.rule("priceImpact"))
        }

        return factory
    }

    private func makePreflight() -> SubtensorStakingPreflight {
        SubtensorStakingPreflight(
            hotkeyExists: true,
            subnetExists: true,
            subtokenEnabled: true,
            hasColdkeySwapAnnouncement: false,
            isSafeModeActive: false,
            stakeAvailability: nil,
            rootStakeUnlockInterval: 7200,
            lastStakeBlock: 1000,
            minStake: 2_000_000,
            effectiveNominatorMinStake: 20_000_000,
            rootClaimableThreshold: 500_000,
            delegateTake: 11796
        )
    }

    private func makeLatestQuote() -> SubtensorTradeQuote {
        let quote = SubtensorQuote(
            args: SubtensorQuoteArgs(netuid: 64, direction: .stake(taoIn: 4_957_858_206)),
            sim: SubtensorStakingPallet.SimSwapResult(
                taoAmount: 4_955_361_688,
                alphaAmount: 67_054_958_000,
                taoFee: 2_496_518,
                alphaFee: 0,
                taoSlippage: 0,
                alphaSlippage: 0
            ),
            spotPrice: 73_900_000,
            feeRate: 33
        )

        return SubtensorTradeQuote(
            quote: quote,
            amountIn: 5_000_000_000,
            novaFee: SubtensorNovaFee(amount: 42_141_794, beneficiary: beneficiary),
            expectedOut: 67_054_958_000,
            swapMinimumOut: 66_721_355_172,
            minimumOut: 66_721_355_172,
            limitPrice: 74_269_500
        )
    }

    private func makeQuoteContext() -> SubtensorQuoteValidatingContext {
        SubtensorQuoteValidatingContext(
            latestQuote: makeLatestQuote(),
            acknowledgedLimit: 74_169_000,
            tradesUnavailable: false,
            onQuoteRefresh: {}
        )
    }

    private func makeDep(
        netuid: UInt16 = SubtensorStakingPallet.rootNetuid,
        quoteContext: SubtensorQuoteValidatingContext? = nil,
        rootHoldCheck: SubtensorRootHoldCheck? = nil
    ) -> SubtensorStakeValidatingDep {
        SubtensorStakeValidatingDep(
            amount: 5_000_000_000,
            balance: nil,
            fee: nil,
            existentialDeposit: nil,
            preflight: makePreflight(),
            netuid: netuid,
            assetDisplayInfo: AssetBalanceDisplayInfo.units(for: 9),
            onFeeRefresh: {},
            onPreflightRefresh: {},
            quoteContext: quoteContext,
            rootHoldCheck: rootHoldCheck
        )
    }

    private func runRules(for dep: SubtensorStakeValidatingDep) -> [String] {
        let recorder = RuleRecorder()

        ValidatingFixture().validateStake(
            for: dep,
            dataValidationFactory: makeRecordingFactory(recorder),
            selectedLocale: locale,
            onSuccess: {}
        )

        return recorder.names
    }

    func testRootStakeRulesRunInOrder() {
        XCTAssertEqual(
            runRules(for: makeDep()),
            [
                "fee",
                "preflight",
                "spend",
                "feeSpend",
                "reserve",
                "minStake",
                "hotkey",
                "subnetEnabled",
                "coldkeySwap",
                "safeMode"
            ]
        )
    }

    func testSubnetBuyRulesRunInOrder() {
        XCTAssertEqual(
            runRules(for: makeDep(netuid: 64, quoteContext: makeQuoteContext())),
            [
                "fee",
                "preflight",
                "tradesAvailable",
                "freshQuote",
                "tolerance",
                "spend",
                "feeSpend",
                "reserve",
                "minStake",
                "hotkey",
                "subnetEnabled",
                "coldkeySwap",
                "safeMode",
                "priceImpact"
            ]
        )
    }

    func testAddStakeHoldCheckRunsTheRootUnlockRuleBeforeTheNetworkStateRules() {
        XCTAssertEqual(
            runRules(for: makeDep(rootHoldCheck: SubtensorRootHoldCheck(currentBlock: 5000, blockTime: 12000))),
            [
                "fee",
                "preflight",
                "spend",
                "feeSpend",
                "reserve",
                "minStake",
                "hotkey",
                "subnetEnabled",
                "rootHold",
                "coldkeySwap",
                "safeMode"
            ]
        )
    }

    func testSubnetMinimumStakeRunsOnTheAmountNetOfTheNovaFee() {
        let factory = makeRecordingFactory(RuleRecorder())

        _ = ValidatingFixture().createStakeValidations(
            for: makeDep(netuid: 64, quoteContext: makeQuoteContext()),
            dataValidationFactory: factory,
            selectedLocale: locale
        )

        let stakedCaptor = ArgumentCaptor<Balance?>()
        let swapFeeCaptor = ArgumentCaptor<Balance?>()
        let novaFeeCaptor = ArgumentCaptor<Bool>()

        verify(factory).hasMinStakeAmount(
            stakedAmount: stakedCaptor.capture(),
            minStake: any(),
            quotedSwapFee: swapFeeCaptor.capture(),
            includesNovaFee: novaFeeCaptor.capture(),
            locale: any()
        )

        XCTAssertEqual(stakedCaptor.value ?? nil, 4_957_858_206)
        XCTAssertEqual(swapFeeCaptor.value ?? nil, 2_496_518)
        XCTAssertEqual(novaFeeCaptor.value, true)
    }

    func testRootMinimumStakeRunsOnTheWholeAmountWithoutNovaFee() {
        let factory = makeRecordingFactory(RuleRecorder())

        _ = ValidatingFixture().createStakeValidations(
            for: makeDep(),
            dataValidationFactory: factory,
            selectedLocale: locale
        )

        let stakedCaptor = ArgumentCaptor<Balance?>()
        let novaFeeCaptor = ArgumentCaptor<Bool>()

        verify(factory).hasMinStakeAmount(
            stakedAmount: stakedCaptor.capture(),
            minStake: any(),
            quotedSwapFee: any(),
            includesNovaFee: novaFeeCaptor.capture(),
            locale: any()
        )

        XCTAssertEqual(stakedCaptor.value ?? nil, 5_000_000_000)
        XCTAssertEqual(novaFeeCaptor.value, false)
    }

    func testToleranceRuleChecksTheLatestQuoteAgainstTheAcknowledgedLimit() {
        let factory = makeRecordingFactory(RuleRecorder())
        let quoteContext = makeQuoteContext()

        _ = ValidatingFixture().createStakeValidations(
            for: makeDep(netuid: 64, quoteContext: quoteContext),
            dataValidationFactory: factory,
            selectedLocale: locale
        )

        let quoteCaptor = ArgumentCaptor<SubtensorTradeQuote?>()
        let limitCaptor = ArgumentCaptor<Balance?>()

        verify(factory).orderWithinSlippageTolerance(
            quote: quoteCaptor.capture(),
            limitPrice: limitCaptor.capture(),
            locale: any()
        )

        XCTAssertEqual(quoteCaptor.value ?? nil, quoteContext.latestQuote)
        XCTAssertEqual(limitCaptor.value ?? nil, 74_169_000)
    }
}
