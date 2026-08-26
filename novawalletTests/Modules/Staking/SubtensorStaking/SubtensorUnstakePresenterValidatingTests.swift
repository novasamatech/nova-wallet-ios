import BigInt
import Cuckoo
@testable import novawallet
import XCTest

final class SubtensorUnstakePresenterValidatingTests: XCTestCase {
    private struct ValidatingFixture: SubtensorUnstakePresenterValidating {}

    private let locale = Locale(identifier: "en")

    private func makePassingValidator() -> DataValidating {
        ErrorConditionViolation(onError: {}, preservesCondition: { true })
    }

    private func makeStubbedFactory() -> MockSubtensorStakingValidationFactoryProtocol {
        let factory = MockSubtensorStakingValidationFactoryProtocol()

        stub(factory) { stub in
            when(stub.has(fee: any(), locale: any(), onError: any())).thenReturn(makePassingValidator())
            when(stub.hasPreflight(any(), locale: any(), onRetry: any())).thenReturn(makePassingValidator())
            when(stub.positionsAreFresh(syncFailed: any(), locale: any(), onRetry: any()))
                .thenReturn(makePassingValidator())
            when(stub.canPayFeeFromStakeOtherwiseWarns(transferable: any(), fee: any(), locale: any()))
                .thenReturn(makePassingValidator())
            when(
                stub.unstakeNotExceedsAvailable(
                    amount: any(),
                    available: any(),
                    assetDisplayInfo: any(),
                    locale: any()
                )
            ).thenReturn(makePassingValidator())
            when(
                stub.unstakeAboveMinTaoOut(
                    taoOut: any(),
                    minAmount: any(),
                    isFullUnstake: any(),
                    locale: any()
                )
            ).thenReturn(makePassingValidator())
            when(
                stub.remainderNotBelowNominatorMin(
                    remainder: any(),
                    nominatorMinStake: any(),
                    onUnstakeAll: any(),
                    locale: any()
                )
            ).thenReturn(makePassingValidator())
            when(
                stub.rootUnlockIntervalElapsed(
                    currentBlock: any(),
                    lastStakeBlock: any(),
                    unlockInterval: any(),
                    blockTime: any(),
                    locale: any()
                )
            ).thenReturn(makePassingValidator())
            when(stub.claimFirstAdvisory(claimable: any(), threshold: any(), locale: any()))
                .thenReturn(makePassingValidator())
            when(stub.noColdkeySwapInProgress(hasAnnouncement: any(), locale: any()))
                .thenReturn(makePassingValidator())
            when(stub.safeModeInactive(safeModeActive: any(), locale: any())).thenReturn(makePassingValidator())
            when(stub.hasFreshQuote(any(), for: any(), locale: any(), onRetry: any()))
                .thenReturn(makePassingValidator())
            when(stub.orderWithinSlippageTolerance(quote: any(), limitPrice: any(), locale: any()))
                .thenReturn(makePassingValidator())
            when(stub.priceImpactAcceptable(quote: any(), locale: any())).thenReturn(makePassingValidator())
        }

        return factory
    }

    private func makeDep(
        netuid: UInt16 = SubtensorStakingPallet.rootNetuid,
        quoteContext: SubtensorQuoteValidatingContext? = nil,
        onUnstakeAll: (() -> Void)? = nil,
        positionsSyncFailed: Bool = false,
        onPositionsRefresh: (() -> Void)? = nil
    ) -> SubtensorUnstakeValidatingDep {
        SubtensorUnstakeValidatingDep(
            netuid: netuid,
            amount: 1_000_000_000,
            stakedAmount: 5_000_000_000,
            isFullUnstake: false,
            balance: nil,
            fee: nil,
            preflight: nil,
            claimablePayout: nil,
            currentBlock: nil,
            blockTime: 12000,
            assetDisplayInfo: AssetBalanceDisplayInfo.units(for: 9),
            onFeeRefresh: {},
            onPreflightRefresh: {},
            onUnstakeAll: onUnstakeAll,
            quoteContext: quoteContext,
            positionsSyncFailed: positionsSyncFailed,
            onPositionsRefresh: onPositionsRefresh
        )
    }

    func testUnstakeValidationListContainsEveryRule() {
        let factory = makeStubbedFactory()

        let validations = ValidatingFixture().createUnstakeValidations(
            for: makeDep(),
            dataValidationFactory: factory,
            selectedLocale: locale
        )

        XCTAssertEqual(validations.count, 11)

        verify(factory).positionsAreFresh(syncFailed: any(), locale: any(), onRetry: any())
        verify(factory).has(fee: any(), locale: any(), onError: any())
        verify(factory).hasPreflight(any(), locale: any(), onRetry: any())
        verify(factory).canPayFeeFromStakeOtherwiseWarns(transferable: any(), fee: any(), locale: any())
        verify(factory).unstakeNotExceedsAvailable(
            amount: any(),
            available: any(),
            assetDisplayInfo: any(),
            locale: any()
        )
        verify(factory).unstakeAboveMinTaoOut(
            taoOut: any(),
            minAmount: any(),
            isFullUnstake: any(),
            locale: any()
        )
        verify(factory).remainderNotBelowNominatorMin(
            remainder: any(),
            nominatorMinStake: any(),
            onUnstakeAll: any(),
            locale: any()
        )
        verify(factory).rootUnlockIntervalElapsed(
            currentBlock: any(),
            lastStakeBlock: any(),
            unlockInterval: any(),
            blockTime: any(),
            locale: any()
        )
        verify(factory).claimFirstAdvisory(claimable: any(), threshold: any(), locale: any())
        verify(factory).noColdkeySwapInProgress(hasAnnouncement: any(), locale: any())
        verify(factory).safeModeInactive(safeModeActive: any(), locale: any())
    }

    func testRootUnstakeValidationListSkipsQuoteRules() {
        let factory = makeStubbedFactory()

        _ = ValidatingFixture().createUnstakeValidations(
            for: makeDep(),
            dataValidationFactory: factory,
            selectedLocale: locale
        )

        verify(factory, never()).hasFreshQuote(any(), for: any(), locale: any(), onRetry: any())
        verify(factory, never()).orderWithinSlippageTolerance(quote: any(), limitPrice: any(), locale: any())
        verify(factory, never()).priceImpactAcceptable(quote: any(), locale: any())
    }

    func testSubnetUnstakeValidationListAppendsQuoteRules() {
        let factory = makeStubbedFactory()

        let context = SubtensorQuoteValidatingContext(
            args: SubtensorQuoteArgs(netuid: 1, direction: .unstake(alphaIn: 1_000_000_000)),
            quote: nil,
            limitPrice: 7_644_839,
            onQuoteRefresh: {}
        )

        let validations = ValidatingFixture().createUnstakeValidations(
            for: makeDep(netuid: 1, quoteContext: context),
            dataValidationFactory: factory,
            selectedLocale: locale
        )

        XCTAssertEqual(validations.count, 13)

        verify(factory).hasFreshQuote(any(), for: any(), locale: any(), onRetry: any())
        verify(factory).orderWithinSlippageTolerance(quote: any(), limitPrice: any(), locale: any())
        verify(factory).priceImpactAcceptable(quote: any(), locale: any())
    }

    func testSubnetUnstakeValidationListSkipsTheRootUnlockHold() {
        let factory = makeStubbedFactory()

        let validations = ValidatingFixture().createUnstakeValidations(
            for: makeDep(netuid: 1),
            dataValidationFactory: factory,
            selectedLocale: locale
        )

        XCTAssertEqual(validations.count, 10)

        verify(factory, never()).rootUnlockIntervalElapsed(
            currentBlock: any(),
            lastStakeBlock: any(),
            unlockInterval: any(),
            blockTime: any(),
            locale: any()
        )
    }

    func testStalePositionsRuleForwardsTheFailedSyncFlag() {
        let factory = makeStubbedFactory()

        _ = ValidatingFixture().createUnstakeValidations(
            for: makeDep(positionsSyncFailed: true),
            dataValidationFactory: factory,
            selectedLocale: locale
        )

        let captor = ArgumentCaptor<Bool>()

        verify(factory).positionsAreFresh(syncFailed: captor.capture(), locale: any(), onRetry: any())

        XCTAssertEqual(captor.value, true)
    }

    func testFailedPositionsSyncBlocksUnstake() {
        let factory = makeStubbedFactory()

        stub(factory) { stub in
            when(stub.positionsAreFresh(syncFailed: any(), locale: any(), onRetry: any()))
                .thenReturn(ErrorConditionViolation(onError: {}, preservesCondition: { false }))
        }

        var proceeded = false

        ValidatingFixture().validateUnstake(
            for: makeDep(positionsSyncFailed: true),
            dataValidationFactory: factory,
            selectedLocale: locale
        ) {
            proceeded = true
        }

        XCTAssertFalse(proceeded)
    }

    func testDustRuleForwardsTheUnstakeAllOfferWhenAvailable() {
        let factory = makeStubbedFactory()

        _ = ValidatingFixture().createUnstakeValidations(
            for: makeDep(onUnstakeAll: {}),
            dataValidationFactory: factory,
            selectedLocale: locale
        )

        let captor = ArgumentCaptor<(() -> Void)?>()

        verify(factory).remainderNotBelowNominatorMin(
            remainder: any(),
            nominatorMinStake: any(),
            onUnstakeAll: captor.capture(),
            locale: any()
        )

        XCTAssertNotNil(captor.value ?? nil)
    }

    func testDustRuleDropsTheUnstakeAllOfferWhenAbsent() {
        let factory = makeStubbedFactory()

        _ = ValidatingFixture().createUnstakeValidations(
            for: makeDep(),
            dataValidationFactory: factory,
            selectedLocale: locale
        )

        let captor = ArgumentCaptor<(() -> Void)?>()

        verify(factory).remainderNotBelowNominatorMin(
            remainder: any(),
            nominatorMinStake: any(),
            onUnstakeAll: captor.capture(),
            locale: any()
        )

        XCTAssertNil(captor.value ?? nil)
    }
}
