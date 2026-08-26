import XCTest
import Cuckoo
import BigInt
@testable import novawallet

final class SubtensorStakePresenterValidatingTests: XCTestCase {
    private struct ValidatingFixture: SubtensorStakePresenterValidating {}

    private let locale = Locale(identifier: "en")

    private func makePassingValidator() -> DataValidating {
        ErrorConditionViolation(onError: {}, preservesCondition: { true })
    }

    private func makeStubbedFactory() -> MockSubtensorStakingValidationFactoryProtocol {
        let factory = MockSubtensorStakingValidationFactoryProtocol()

        stub(factory) { stub in
            when(stub.has(fee: any(), locale: any(), onError: any())).thenReturn(makePassingValidator())
            when(stub.hasPreflight(any(), locale: any(), onRetry: any())).thenReturn(makePassingValidator())
            when(stub.canSpendAmount(balance: any(), spendingAmount: any(), locale: any()))
                .thenReturn(makePassingValidator())
            when(
                stub.canPayFeeSpendingAmount(
                    balance: any(),
                    fee: any(),
                    spendingAmount: any(),
                    asset: any(),
                    locale: any()
                )
            ).thenReturn(makePassingValidator())
            when(
                stub.retainsFeeReserveAfterStake(
                    balance: any(),
                    amount: any(),
                    fee: any(),
                    existentialDeposit: any(),
                    locale: any()
                )
            ).thenReturn(makePassingValidator())
            when(stub.hasMinStakeAmount(amount: any(), minStake: any(), quotedSwapFee: any(), locale: any()))
                .thenReturn(makePassingValidator())
            when(stub.hotkeyIsRegistered(hotkeyExists: any(), locale: any())).thenReturn(makePassingValidator())
            when(
                stub.subnetStakingEnabled(
                    netuid: any(),
                    subnetExists: any(),
                    subtokenEnabled: any(),
                    locale: any()
                )
            ).thenReturn(makePassingValidator())
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
        quoteContext: SubtensorQuoteValidatingContext? = nil
    ) -> SubtensorStakeValidatingDep {
        SubtensorStakeValidatingDep(
            amount: 1_000_000_000,
            balance: nil,
            fee: nil,
            existentialDeposit: nil,
            preflight: nil,
            netuid: quoteContext != nil ? 1 : SubtensorStakingPallet.rootNetuid,
            assetDisplayInfo: AssetBalanceDisplayInfo.units(for: 9),
            onFeeRefresh: {},
            onPreflightRefresh: {},
            quoteContext: quoteContext
        )
    }

    func testStakeValidationListContainsEveryRule() {
        let factory = makeStubbedFactory()

        let validations = ValidatingFixture().createStakeValidations(
            for: makeDep(),
            dataValidationFactory: factory,
            selectedLocale: locale
        )

        XCTAssertEqual(validations.count, 10)

        verify(factory).has(fee: any(), locale: any(), onError: any())
        verify(factory).hasPreflight(any(), locale: any(), onRetry: any())
        verify(factory).canSpendAmount(balance: any(), spendingAmount: any(), locale: any())
        verify(factory).canPayFeeSpendingAmount(
            balance: any(),
            fee: any(),
            spendingAmount: any(),
            asset: any(),
            locale: any()
        )
        verify(factory).retainsFeeReserveAfterStake(
            balance: any(),
            amount: any(),
            fee: any(),
            existentialDeposit: any(),
            locale: any()
        )
        verify(factory).hasMinStakeAmount(amount: any(), minStake: any(), quotedSwapFee: any(), locale: any())
        verify(factory).hotkeyIsRegistered(hotkeyExists: any(), locale: any())
        verify(factory).subnetStakingEnabled(
            netuid: any(),
            subnetExists: any(),
            subtokenEnabled: any(),
            locale: any()
        )
        verify(factory).noColdkeySwapInProgress(hasAnnouncement: any(), locale: any())
        verify(factory).safeModeInactive(safeModeActive: any(), locale: any())
    }

    func testRootStakeValidationListSkipsQuoteRules() {
        let factory = makeStubbedFactory()

        _ = ValidatingFixture().createStakeValidations(
            for: makeDep(),
            dataValidationFactory: factory,
            selectedLocale: locale
        )

        verify(factory, never()).hasFreshQuote(any(), for: any(), locale: any(), onRetry: any())
        verify(factory, never()).orderWithinSlippageTolerance(quote: any(), limitPrice: any(), locale: any())
        verify(factory, never()).priceImpactAcceptable(quote: any(), locale: any())
    }

    func testSubnetStakeValidationListAppendsQuoteRules() {
        let factory = makeStubbedFactory()

        let context = SubtensorQuoteValidatingContext(
            args: SubtensorQuoteArgs(netuid: 1, direction: .stake(taoIn: 1_000_000_000)),
            quote: nil,
            limitPrice: 7_721_671,
            onQuoteRefresh: {}
        )

        let validations = ValidatingFixture().createStakeValidations(
            for: makeDep(quoteContext: context),
            dataValidationFactory: factory,
            selectedLocale: locale
        )

        XCTAssertEqual(validations.count, 13)

        verify(factory).hasFreshQuote(any(), for: any(), locale: any(), onRetry: any())
        verify(factory).orderWithinSlippageTolerance(quote: any(), limitPrice: any(), locale: any())
        verify(factory).priceImpactAcceptable(quote: any(), locale: any())
    }
}
