import XCTest
import Cuckoo
import BigInt
@testable import novawallet

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
            when(stub.canPayFeeFromStakeOtherwiseWarns(transferable: any(), fee: any(), locale: any()))
                .thenReturn(makePassingValidator())
            when(stub.unstakeNotExceedsAvailable(amount: any(), available: any(), locale: any()))
                .thenReturn(makePassingValidator())
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
        }

        return factory
    }

    private func makeDep() -> SubtensorUnstakeValidatingDep {
        SubtensorUnstakeValidatingDep(
            amount: 1_000_000_000,
            stakedAmount: 5_000_000_000,
            isFullUnstake: false,
            balance: nil,
            fee: nil,
            preflight: nil,
            claimablePayout: nil,
            currentBlock: nil,
            blockTime: 12_000,
            assetDisplayInfo: AssetBalanceDisplayInfo.units(for: 9),
            onFeeRefresh: {},
            onPreflightRefresh: {}
        )
    }

    func testUnstakeValidationListContainsEveryRule() {
        let factory = makeStubbedFactory()

        let validations = ValidatingFixture().createUnstakeValidations(
            for: makeDep(),
            dataValidationFactory: factory,
            selectedLocale: locale
        )

        XCTAssertEqual(validations.count, 10)

        verify(factory).has(fee: any(), locale: any(), onError: any())
        verify(factory).hasPreflight(any(), locale: any(), onRetry: any())
        verify(factory).canPayFeeFromStakeOtherwiseWarns(transferable: any(), fee: any(), locale: any())
        verify(factory).unstakeNotExceedsAvailable(amount: any(), available: any(), locale: any())
        verify(factory).unstakeAboveMinTaoOut(
            taoOut: any(),
            minAmount: any(),
            isFullUnstake: any(),
            locale: any()
        )
        verify(factory).remainderNotBelowNominatorMin(
            remainder: any(),
            nominatorMinStake: any(),
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
}
