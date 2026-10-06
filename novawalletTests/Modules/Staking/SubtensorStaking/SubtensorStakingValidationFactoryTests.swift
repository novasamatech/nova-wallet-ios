import BigInt
import Cuckoo
import Foundation_iOS
@testable import novawallet
import XCTest

final class SubtensorStakingValidationFactoryTests: XCTestCase {
    private struct Setup {
        let factory: SubtensorStakingValidationFactory
        let presentable: MockSubtensorStakingTestWireframeProtocol
        let view: MockControllerBackedProtocol
    }

    private let locale = Locale(identifier: "en")
    private let taoDisplayInfo = AssetBalanceDisplayInfo(
        displayPrecision: 5,
        assetPrecision: 9,
        symbol: "TAO",
        symbolValueSeparator: " ",
        symbolPosition: .suffix,
        icon: nil
    )
    private let alphaDisplayInfo = AssetBalanceDisplayInfo(
        displayPrecision: 5,
        assetPrecision: 9,
        symbol: "SN64",
        symbolValueSeparator: " ",
        symbolPosition: .suffix,
        icon: nil
    )

    private func makeSetup() -> Setup {
        let presentable = MockSubtensorStakingTestWireframeProtocol()

        let factory = SubtensorStakingValidationFactory(
            presentable: presentable,
            assetDisplayInfo: taoDisplayInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())
        )

        let view = MockControllerBackedProtocol()
        factory.view = view

        return Setup(factory: factory, presentable: presentable, view: view)
    }

    private func run(_ validator: DataValidating) -> (completed: Bool, problem: DataValidationProblem?) {
        var completed = false
        var problem: DataValidationProblem?

        DataValidationRunner(validators: [validator]).runValidation(
            notifyingOnSuccess: { completed = true },
            notifyingOnStop: { problem = $0 },
            notifyingOnResume: nil
        )

        return (completed, problem)
    }

    private func assertCompleted(
        _ result: (completed: Bool, problem: DataValidationProblem?),
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(result.completed, file: file, line: line)
        XCTAssertNil(result.problem, file: file, line: line)
    }

    private func assertError(
        _ result: (completed: Bool, problem: DataValidationProblem?),
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertFalse(result.completed, file: file, line: line)

        guard case .error = result.problem else {
            XCTFail("Expected error, got \(String(describing: result.problem))", file: file, line: line)
            return
        }
    }

    private func assertWarningContinued(
        _ result: (completed: Bool, problem: DataValidationProblem?),
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(result.completed, file: file, line: line)

        guard case .warning = result.problem else {
            XCTFail("Expected warning, got \(String(describing: result.problem))", file: file, line: line)
            return
        }
    }

    func testHasMinStakeAmountPassesAtMinimumWithSwapFee() {
        let setup = makeSetup()

        let validator = setup.factory.hasMinStakeAmount(
            stakedAmount: BigUInt(2_000_100),
            minStake: BigUInt(2_000_000),
            quotedSwapFee: BigUInt(100),
            includesNovaFee: true,
            locale: locale
        )

        assertCompleted(run(validator))
    }

    func testHasMinStakeAmountBlocksBelowMinimum() {
        let setup = makeSetup()

        stub(setup.presentable) { stub in
            when(stub.presentStakeAmountTooLow(any(), minStake: any(), locale: any())).thenDoNothing()
        }

        let validator = setup.factory.hasMinStakeAmount(
            stakedAmount: BigUInt(1_999_999),
            minStake: BigUInt(2_000_000),
            quotedSwapFee: nil,
            includesNovaFee: false,
            locale: locale
        )

        assertError(run(validator))

        verify(setup.presentable).presentStakeAmountTooLow(any(), minStake: any(), locale: any())
    }

    func testSubnetMinimumStakeMessageShowsTheGrossedUpMinimum() {
        let setup = makeSetup()
        let captor = ArgumentCaptor<String>()

        stub(setup.presentable) { stub in
            when(stub.presentStakeAmountTooLow(any(), minStake: any(), locale: any())).thenDoNothing()
        }

        let validator = setup.factory.hasMinStakeAmount(
            stakedAmount: BigUInt(2_001_006),
            minStake: BigUInt(2_000_000),
            quotedSwapFee: BigUInt(1007),
            includesNovaFee: true,
            locale: locale
        )

        assertError(run(validator))

        verify(setup.presentable).presentStakeAmountTooLow(any(), minStake: captor.capture(), locale: any())

        XCTAssertEqual(captor.value, "0.00202 TAO")
    }

    func testRootMinimumStakeMessageShowsTheMinimumWithoutNovaFee() {
        let setup = makeSetup()
        let captor = ArgumentCaptor<String>()

        stub(setup.presentable) { stub in
            when(stub.presentStakeAmountTooLow(any(), minStake: any(), locale: any())).thenDoNothing()
        }

        let validator = setup.factory.hasMinStakeAmount(
            stakedAmount: BigUInt(1_999_999),
            minStake: BigUInt(2_000_000),
            quotedSwapFee: nil,
            includesNovaFee: false,
            locale: locale
        )

        assertError(run(validator))

        verify(setup.presentable).presentStakeAmountTooLow(any(), minStake: captor.capture(), locale: any())

        XCTAssertEqual(captor.value, setup.factory.formatAmount(2_000_000, locale: locale))
    }

    func testRespectsFeeReservePassesAtTheMaximum() {
        let setup = makeSetup()

        let validator = setup.factory.respectsFeeReserve(
            amount: BigUInt(988_500_000),
            transferable: BigUInt(1_000_000_000),
            networkFee: BigUInt(1_500_000),
            locale: locale
        )

        assertCompleted(run(validator))
    }

    func testRespectsFeeReserveBlocksAboveTheMaximumAndNamesIt() {
        let setup = makeSetup()
        let maxAmountCaptor = ArgumentCaptor<String>()
        let reserveCaptor = ArgumentCaptor<String>()

        stub(setup.presentable) { stub in
            when(
                stub.presentFeeReserveRequired(any(), maxAmount: any(), reserve: any(), locale: any())
            ).thenDoNothing()
        }

        let validator = setup.factory.respectsFeeReserve(
            amount: BigUInt(988_500_001),
            transferable: BigUInt(1_000_000_000),
            networkFee: BigUInt(1_500_000),
            locale: locale
        )

        assertError(run(validator))

        verify(setup.presentable).presentFeeReserveRequired(
            any(),
            maxAmount: maxAmountCaptor.capture(),
            reserve: reserveCaptor.capture(),
            locale: any()
        )

        XCTAssertEqual(maxAmountCaptor.value, setup.factory.formatAmount(988_500_000, locale: locale))
        XCTAssertEqual(reserveCaptor.value, setup.factory.formatAmount(10_000_000, locale: locale))
    }

    func testSubnetTradesAvailableBlocksWhenTheNovaFeeIsUnavailable() {
        let setup = makeSetup()

        stub(setup.presentable) { stub in
            when(stub.presentSubnetTradesUnavailable(any(), locale: any())).thenDoNothing()
        }

        let validator = setup.factory.subnetTradesAvailable(tradesUnavailable: true, locale: locale)

        assertError(run(validator))

        verify(setup.presentable).presentSubnetTradesUnavailable(any(), locale: any())
    }

    func testSubnetTradesAvailablePassesWhileTheNovaFeeIsAvailable() {
        let setup = makeSetup()

        let validator = setup.factory.subnetTradesAvailable(tradesUnavailable: false, locale: locale)

        assertCompleted(run(validator))
    }

    func testHotkeyIsRegisteredPasses() {
        let setup = makeSetup()

        let validator = setup.factory.hotkeyIsRegistered(hotkeyExists: true, locale: locale)

        assertCompleted(run(validator))
    }

    func testHotkeyIsRegisteredBlocksWhenMissing() {
        let setup = makeSetup()

        stub(setup.presentable) { stub in
            when(stub.presentHotkeyNotFound(any(), locale: any())).thenDoNothing()
        }

        let validator = setup.factory.hotkeyIsRegistered(hotkeyExists: false, locale: locale)

        assertError(run(validator))

        verify(setup.presentable).presentHotkeyNotFound(any(), locale: any())
    }

    func testSubnetStakingEnabledBlocksRootWithDisabledSubtoken() {
        let setup = makeSetup()

        stub(setup.presentable) { stub in
            when(stub.presentSubnetStakingDisabled(any(), locale: any())).thenDoNothing()
        }

        let validator = setup.factory.subnetStakingEnabled(
            netuid: 0,
            subnetExists: true,
            subtokenEnabled: false,
            locale: locale
        )

        assertError(run(validator))

        verify(setup.presentable).presentSubnetStakingDisabled(any(), locale: any())
    }

    func testSubnetStakingEnabledBlocksDisabledSubtoken() {
        let setup = makeSetup()

        stub(setup.presentable) { stub in
            when(stub.presentSubnetStakingDisabled(any(), locale: any())).thenDoNothing()
        }

        let validator = setup.factory.subnetStakingEnabled(
            netuid: 1,
            subnetExists: true,
            subtokenEnabled: false,
            locale: locale
        )

        assertError(run(validator))

        verify(setup.presentable).presentSubnetStakingDisabled(any(), locale: any())
    }

    func testNoColdkeySwapInProgressPasses() {
        let setup = makeSetup()

        let validator = setup.factory.noColdkeySwapInProgress(hasAnnouncement: false, locale: locale)

        assertCompleted(run(validator))
    }

    func testNoColdkeySwapInProgressBlocksWhenAnnounced() {
        let setup = makeSetup()

        stub(setup.presentable) { stub in
            when(stub.presentColdkeySwapInProgress(any(), locale: any())).thenDoNothing()
        }

        let validator = setup.factory.noColdkeySwapInProgress(hasAnnouncement: true, locale: locale)

        assertError(run(validator))

        verify(setup.presentable).presentColdkeySwapInProgress(any(), locale: any())
    }

    func testSafeModeInactivePasses() {
        let setup = makeSetup()

        let validator = setup.factory.safeModeInactive(safeModeActive: false, locale: locale)

        assertCompleted(run(validator))
    }

    func testSafeModeInactiveBlocksWhenActive() {
        let setup = makeSetup()

        stub(setup.presentable) { stub in
            when(stub.presentSafeModeActive(any(), locale: any())).thenDoNothing()
        }

        let validator = setup.factory.safeModeInactive(safeModeActive: true, locale: locale)

        assertError(run(validator))

        verify(setup.presentable).presentSafeModeActive(any(), locale: any())
    }

    func testCanPayFeeFromStakePassesWhenTransferableCoversFee() {
        let setup = makeSetup()

        let validator = setup.factory.canPayFeeFromStakeOtherwiseWarns(
            transferable: BigUInt(100),
            fee: BigUInt(50),
            existentialDeposit: BigUInt(50),
            locale: locale
        )

        assertCompleted(run(validator))
    }

    func testCanPayFeeFromStakeWarnsWhenTransferableShort() {
        let setup = makeSetup()

        stub(setup.presentable) { stub in
            when(
                stub.presentFeeFromStakeWarning(any(), fee: any(), action: any(), locale: any())
            ).then { (_, _, action: @escaping () -> Void, _) in
                action()
            }
        }

        let validator = setup.factory.canPayFeeFromStakeOtherwiseWarns(
            transferable: BigUInt(10),
            fee: BigUInt(50),
            existentialDeposit: BigUInt(50),
            locale: locale
        )

        assertWarningContinued(run(validator))
    }

    func testBatchedSellIsRefusedWhenFreeTaoMissesTheFeePlusDeposit() {
        let setup = makeSetup()
        let captor = ArgumentCaptor<String>()

        stub(setup.presentable) { stub in
            when(stub.presentBatchedSellFeeNotCovered(any(), requiredAmount: any(), locale: any())).thenDoNothing()
        }

        let validator = setup.factory.canPayBatchedNetworkFee(
            transferable: BigUInt(1_500_499),
            networkFee: BigUInt(1_500_000),
            existentialDeposit: BigUInt(500),
            locale: locale
        )

        assertError(run(validator))

        verify(setup.presentable).presentBatchedSellFeeNotCovered(
            any(),
            requiredAmount: captor.capture(),
            locale: any()
        )

        XCTAssertEqual(captor.value, "0.00151 TAO")
    }

    func testBatchedSellProceedsWhenFreeTaoCoversTheFeePlusDeposit() {
        let setup = makeSetup()

        let validator = setup.factory.canPayBatchedNetworkFee(
            transferable: BigUInt(1_500_500),
            networkFee: BigUInt(1_500_000),
            existentialDeposit: BigUInt(500),
            locale: locale
        )

        assertCompleted(run(validator))
    }

    func testBatchedSellIsRefusedWhileTheExistentialDepositIsUnknown() {
        let setup = makeSetup()

        stub(setup.presentable) { stub in
            when(stub.presentBatchedSellFeeNotCovered(any(), requiredAmount: any(), locale: any())).thenDoNothing()
        }

        let validator = setup.factory.canPayBatchedNetworkFee(
            transferable: BigUInt(10_000_000_000),
            networkFee: BigUInt(1_500_000),
            existentialDeposit: nil,
            locale: locale
        )

        assertError(run(validator))
    }

    func testSellPlanPassesAPartialSell() {
        let setup = makeSetup()

        let validator = setup.factory.sellPlanAllows(
            makeSellPlanInput(requestedAlpha: 5_000_000_000),
            assetDisplayInfo: alphaDisplayInfo,
            onUnstakeAll: nil,
            locale: locale
        )

        assertCompleted(run(validator))
    }

    func testSellPlanAboveTheAvailableAlphaNamesTheMaxInAlpha() {
        let setup = makeSetup()
        let captor = ArgumentCaptor<String>()

        stub(setup.presentable) { stub in
            when(stub.presentUnstakeExceedsAvailable(any(), available: any(), locale: any())).thenDoNothing()
        }

        let validator = setup.factory.sellPlanAllows(
            makeSellPlanInput(requestedAlpha: 8_000_000_000, available: 6_000_000_000),
            assetDisplayInfo: alphaDisplayInfo,
            onUnstakeAll: nil,
            locale: locale
        )

        assertError(run(validator))

        verify(setup.presentable).presentUnstakeExceedsAvailable(any(), available: captor.capture(), locale: any())

        XCTAssertEqual(
            captor.value,
            setup.factory.formatAmount(6_000_000_000, assetDisplayInfo: alphaDisplayInfo, locale: locale)
        )
    }

    func testSellPlanBelowTheGuaranteedMinimumOutIsBlocked() {
        let setup = makeSetup()

        stub(setup.presentable) { stub in
            when(stub.presentUnstakeAmountTooLow(any(), minAmount: any(), locale: any())).thenDoNothing()
        }

        let validator = setup.factory.sellPlanAllows(
            makeSellPlanInput(requestedAlpha: 5_000_000_000, minimumTaoOut: 1_999_999),
            assetDisplayInfo: alphaDisplayInfo,
            onUnstakeAll: nil,
            locale: locale
        )

        assertError(run(validator))

        verify(setup.presentable).presentUnstakeAmountTooLow(any(), minAmount: any(), locale: any())
    }

    func testSellPlanWarnsAboutASweptRemainderAndProceeds() {
        let setup = makeSetup()
        let remainderCaptor = ArgumentCaptor<String>()

        stub(setup.presentable) { stub in
            when(
                stub.presentDustRemainderWarning(
                    any(),
                    remainder: any(),
                    minStake: any(),
                    action: any(),
                    unstakeAllAction: any(),
                    locale: any()
                )
            ).then { (_, _, _, action: @escaping () -> Void, _, _) in
                action()
            }
        }

        let validator = setup.factory.sellPlanAllows(
            makeSellPlanInput(requestedAlpha: 9_800_000_000),
            assetDisplayInfo: alphaDisplayInfo,
            onUnstakeAll: nil,
            locale: locale
        )

        assertWarningContinued(run(validator))

        verify(setup.presentable).presentDustRemainderWarning(
            any(),
            remainder: remainderCaptor.capture(),
            minStake: any(),
            action: any(),
            unstakeAllAction: any(),
            locale: any()
        )

        XCTAssertEqual(remainderCaptor.value, setup.factory.formatAmount(14_686_200, locale: locale))
    }

    func testUnstakeAllChoiceOnASweptRemainderDoesNotResumeTheStoppedRun() {
        let setup = makeSetup()

        var unstakeAllCalled = false

        stub(setup.presentable) { stub in
            when(
                stub.presentDustRemainderWarning(
                    any(),
                    remainder: any(),
                    minStake: any(),
                    action: any(),
                    unstakeAllAction: any(),
                    locale: any()
                )
            ).then { (_, _, _, _, unstakeAllAction: (() -> Void)?, _) in
                unstakeAllAction?()
            }
        }

        let validator = setup.factory.sellPlanAllows(
            makeSellPlanInput(requestedAlpha: 9_800_000_000),
            assetDisplayInfo: alphaDisplayInfo,
            onUnstakeAll: { unstakeAllCalled = true },
            locale: locale
        )

        let result = run(validator)

        XCTAssertTrue(unstakeAllCalled)
        XCTAssertFalse(result.completed)
    }

    func testSellPlanBlocksALockedRemainderTheNetworkWouldErase() {
        let setup = makeSetup()

        stub(setup.presentable) { stub in
            when(
                stub.presentLockedRemainder(any(), remainder: any(), minStake: any(), locale: any())
            ).thenDoNothing()
        }

        let validator = setup.factory.sellPlanAllows(
            makeSellPlanInput(requestedAlpha: 9_800_000_000, available: 9_900_000_000),
            assetDisplayInfo: alphaDisplayInfo,
            onUnstakeAll: nil,
            locale: locale
        )

        assertError(run(validator))

        verify(setup.presentable).presentLockedRemainder(any(), remainder: any(), minStake: any(), locale: any())
    }

    func testSellPlanWithoutInputsIsBlocked() {
        let setup = makeSetup()

        stub(setup.presentable) { stub in
            when(stub.presentUnstakeExceedsAvailable(any(), available: any(), locale: any())).thenDoNothing()
        }

        let validator = setup.factory.sellPlanAllows(
            nil,
            assetDisplayInfo: alphaDisplayInfo,
            onUnstakeAll: nil,
            locale: locale
        )

        assertError(run(validator))
    }

    func testRootUnlockIntervalPassesWhenDisabled() {
        let setup = makeSetup()

        let validator = setup.factory.rootUnlockIntervalElapsed(
            currentBlock: 1000,
            lastStakeBlock: 999,
            unlockInterval: 0,
            blockTime: 12000,
            locale: locale
        )

        assertCompleted(run(validator))
    }

    func testRootUnlockIntervalPassesWhenElapsed() {
        let setup = makeSetup()

        let validator = setup.factory.rootUnlockIntervalElapsed(
            currentBlock: 1000,
            lastStakeBlock: 100,
            unlockInterval: 900,
            blockTime: 12000,
            locale: locale
        )

        assertCompleted(run(validator))
    }

    func testRootUnlockIntervalBlocksBeforeElapsed() {
        let setup = makeSetup()

        stub(setup.presentable) { stub in
            when(stub.presentUnstakeLocked(any(), eta: any(), locale: any())).thenDoNothing()
        }

        let validator = setup.factory.rootUnlockIntervalElapsed(
            currentBlock: 1000,
            lastStakeBlock: 900,
            unlockInterval: 900,
            blockTime: 12000,
            locale: locale
        )

        assertError(run(validator))

        verify(setup.presentable).presentUnstakeLocked(any(), eta: any(), locale: any())
    }

    func testHasPreflightPassesWhenLoaded() {
        let setup = makeSetup()

        let preflight = SubtensorStakingPreflight(
            hotkeyExists: true,
            subnetExists: true,
            subtokenEnabled: true,
            hasColdkeySwapAnnouncement: false,
            isSafeModeActive: false,
            stakeAvailability: nil,
            rootStakeUnlockInterval: 0,
            lastStakeBlock: nil,
            minStake: 2_000_000,
            effectiveNominatorMinStake: 20_000_000,
            rootClaimableThreshold: 500_000,
            delegateTake: 11796
        )

        let validator = setup.factory.hasPreflight(preflight, locale: locale, onRetry: {})

        assertCompleted(run(validator))
    }

    func testHasPreflightBlocksWithRetryWhenMissing() {
        let setup = makeSetup()

        var retried = false

        stub(setup.presentable) { stub in
            when(
                stub.presentPreflightNotReceived(any(), onRetry: any(), locale: any())
            ).then { (_, onRetry: @escaping () -> Void, _) in
                onRetry()
            }
        }

        let validator = setup.factory.hasPreflight(nil, locale: locale, onRetry: { retried = true })

        assertError(run(validator))

        XCTAssertTrue(retried)
    }

    func testPositionsAreFreshPassesWhileTheSyncSucceeds() {
        let setup = makeSetup()

        let validator = setup.factory.positionsAreFresh(
            syncFailed: false,
            locale: locale,
            onRetry: {}
        )

        assertCompleted(run(validator))
    }

    func testPositionsAreFreshBlocksWithRetryAfterAFailedSync() {
        let setup = makeSetup()

        var retried = false

        stub(setup.presentable) { stub in
            when(
                stub.presentStalePositions(any(), onRetry: any(), locale: any())
            ).then { (_, onRetry: @escaping () -> Void, _) in
                onRetry()
            }
        }

        let validator = setup.factory.positionsAreFresh(
            syncFailed: true,
            locale: locale,
            onRetry: { retried = true }
        )

        assertError(run(validator))

        XCTAssertTrue(retried)
    }

    func testHasMinStakeAmountBlocksWhenMinStakeMissing() {
        let setup = makeSetup()

        stub(setup.presentable) { stub in
            when(stub.presentStakeAmountTooLow(any(), minStake: any(), locale: any())).thenDoNothing()
        }

        let validator = setup.factory.hasMinStakeAmount(
            stakedAmount: BigUInt(5_000_000),
            minStake: nil,
            quotedSwapFee: nil,
            includesNovaFee: false,
            locale: locale
        )

        assertError(run(validator))
    }

    func testRootUnlockIntervalPassesWhenIntervalMissing() {
        let setup = makeSetup()

        let validator = setup.factory.rootUnlockIntervalElapsed(
            currentBlock: 100,
            lastStakeBlock: 90,
            unlockInterval: nil,
            blockTime: 12000,
            locale: locale
        )

        assertCompleted(run(validator))
    }

    func testRootUnlockIntervalBlocksWhenCurrentBlockMissing() {
        let setup = makeSetup()

        stub(setup.presentable) { stub in
            when(stub.presentUnstakeLocked(any(), eta: any(), locale: any())).thenDoNothing()
        }

        let validator = setup.factory.rootUnlockIntervalElapsed(
            currentBlock: nil,
            lastStakeBlock: 90,
            unlockInterval: 10,
            blockTime: 12000,
            locale: locale
        )

        assertError(run(validator))
    }

    private func makeSellPlanInput(
        requestedAlpha: Balance,
        available: Balance = 10_000_000_000,
        minimumTaoOut: Balance = 700_000_000
    ) -> SubtensorSellPlanInput {
        SubtensorSellPlanInput(
            requestedAlpha: requestedAlpha,
            positionAlpha: 10_000_000_000,
            availability: SubtensorStakingPallet.StakeAvailability(
                total: 10_000_000_000,
                locked: 10_000_000_000 - available,
                available: available
            ),
            minimumTaoOut: minimumTaoOut,
            sellLimitPrice: 73_431_000,
            isOwnHotkey: false,
            minStake: 2_000_000,
            nominatorMinStake: 20_000_000
        )
    }

    private func makeStakeQuote(
        taoAmount: Balance = 999_496_453,
        alphaAmount: Balance = 130_082_405_209,
        spotPrice: Balance = 7_683_255,
        capturedAt: Date = Date()
    ) -> SubtensorTradeQuote {
        let quote = SubtensorQuote(
            args: SubtensorQuoteArgs(netuid: 1, direction: .stake(taoIn: 1_000_000_000)),
            sim: SubtensorStakingPallet.SimSwapResult(
                taoAmount: taoAmount,
                alphaAmount: alphaAmount,
                taoFee: 503_547,
                alphaFee: 0,
                taoSlippage: 0,
                alphaSlippage: 70_762_340
            ),
            spotPrice: spotPrice,
            feeRate: 33,
            capturedAt: capturedAt
        )

        return SubtensorTradeQuote(
            quote: quote,
            amountIn: 1_000_000_000,
            novaFee: nil,
            expectedOut: alphaAmount,
            swapMinimumOut: 129_440_434_978,
            minimumOut: 129_440_434_978,
            limitPrice: 7_721_671
        )
    }

    private func makeChutesBuyQuote(alphaOut: Balance) -> SubtensorTradeQuote {
        let quote = SubtensorQuote(
            args: SubtensorQuoteArgs(netuid: 64, direction: .stake(taoIn: 4_957_858_206)),
            sim: SubtensorStakingPallet.SimSwapResult(
                taoAmount: 4_955_361_688,
                alphaAmount: alphaOut,
                taoFee: 2_496_518,
                alphaFee: 0,
                taoSlippage: 0,
                alphaSlippage: 0
            ),
            spotPrice: 73_800_000,
            feeRate: 33
        )

        return SubtensorTradeQuote(
            quote: quote,
            amountIn: 5_000_000_000,
            novaFee: nil,
            expectedOut: alphaOut,
            swapMinimumOut: 66_811_763_513,
            minimumOut: 66_811_763_513,
            limitPrice: 74_169_000
        )
    }

    private func makeChutesSellQuote(taoOut: Balance) -> SubtensorTradeQuote {
        let quote = SubtensorQuote(
            args: SubtensorQuoteArgs(netuid: 64, direction: .unstake(alphaIn: 56_200_000_000)),
            sim: SubtensorStakingPallet.SimSwapResult(
                taoAmount: taoOut,
                alphaAmount: 56_171_700_618,
                taoFee: 0,
                alphaFee: 28_299_382,
                taoSlippage: 0,
                alphaSlippage: 0
            ),
            spotPrice: 73_800_000,
            feeRate: 33
        )

        return SubtensorTradeQuote(
            quote: quote,
            amountIn: 56_200_000_000,
            novaFee: nil,
            expectedOut: taoOut,
            swapMinimumOut: 4_124_744_148,
            minimumOut: 4_124_744_148,
            limitPrice: 73_431_000
        )
    }

    func testHasFreshQuotePassesForARecentQuote() {
        let setup = makeSetup()

        let validator = setup.factory.hasFreshQuote(makeStakeQuote(), locale: locale, onRetry: {})

        assertCompleted(run(validator))
    }

    func testHasFreshQuoteBlocksWhenQuoteMissing() {
        let setup = makeSetup()

        stub(setup.presentable) { stub in
            when(stub.presentQuoteMissing(any(), onRetry: any(), locale: any())).thenDoNothing()
        }

        let validator = setup.factory.hasFreshQuote(nil, locale: locale, onRetry: {})

        assertError(run(validator))

        verify(setup.presentable).presentQuoteMissing(any(), onRetry: any(), locale: any())
    }

    func testHasFreshQuoteBlocksWhenQuoteOlderThanStalenessWindow() {
        let setup = makeSetup()

        stub(setup.presentable) { stub in
            when(stub.presentQuoteMissing(any(), onRetry: any(), locale: any())).thenDoNothing()
        }

        let validator = setup.factory.hasFreshQuote(
            makeStakeQuote(capturedAt: Date(timeIntervalSinceNow: -60)),
            locale: locale,
            onRetry: {}
        )

        assertError(run(validator))
    }

    func testHasFreshQuotePassesWithinStalenessWindow() {
        let setup = makeSetup()

        let validator = setup.factory.hasFreshQuote(
            makeStakeQuote(capturedAt: Date(timeIntervalSinceNow: -5)),
            locale: locale,
            onRetry: {}
        )

        assertCompleted(run(validator))
    }

    func testBuyWhosePostTradePriceCrossesTheLimitIsBlockedAlthoughItsAveragePriceIsInside() {
        let setup = makeSetup()

        stub(setup.presentable) { stub in
            when(stub.presentOrderBeyondTolerance(any(), locale: any())).thenDoNothing()
        }

        let validator = setup.factory.orderWithinSlippageTolerance(
            quote: makeChutesBuyQuote(alphaOut: 66_964_347_135),
            limitPrice: 74_169_000,
            locale: locale
        )

        assertError(run(validator))

        verify(setup.presentable).presentOrderBeyondTolerance(any(), locale: any())
    }

    func testSellWhosePostTradePriceCrossesTheLimitIsBlockedAlthoughItsAveragePriceIsInside() {
        let setup = makeSetup()

        stub(setup.presentable) { stub in
            when(stub.presentOrderBeyondTolerance(any(), locale: any())).thenDoNothing()
        }

        let validator = setup.factory.orderWithinSlippageTolerance(
            quote: makeChutesSellQuote(taoOut: 4_133_000_000),
            limitPrice: 73_431_000,
            locale: locale
        )

        assertError(run(validator))

        verify(setup.presentable).presentOrderBeyondTolerance(any(), locale: any())
    }

    func testOrderFillableAtTheAcknowledgedLimitPasses() {
        let setup = makeSetup()

        let validator = setup.factory.orderWithinSlippageTolerance(
            quote: makeChutesBuyQuote(alphaOut: 67_054_958_000),
            limitPrice: 74_169_000,
            locale: locale
        )

        assertCompleted(run(validator))
    }

    func testOrderWithoutAnAcknowledgedLimitIsBlocked() {
        let setup = makeSetup()

        stub(setup.presentable) { stub in
            when(stub.presentOrderBeyondTolerance(any(), locale: any())).thenDoNothing()
        }

        let validator = setup.factory.orderWithinSlippageTolerance(
            quote: makeChutesBuyQuote(alphaOut: 67_054_958_000),
            limitPrice: nil,
            locale: locale
        )

        assertError(run(validator))
    }

    func testPriceImpactBelowThresholdPasses() {
        let setup = makeSetup()

        let validator = setup.factory.priceImpactAcceptable(
            quote: makeStakeQuote(),
            locale: locale
        )

        assertCompleted(run(validator))
    }

    func testPriceImpactAtTenPercentWarns() {
        let setup = makeSetup()

        stub(setup.presentable) { stub in
            when(
                stub.presentHighPriceImpact(any(), impact: any(), action: any(), locale: any())
            ).then { (_, _, action: @escaping () -> Void, _) in
                action()
            }
        }

        let quote = makeStakeQuote(
            taoAmount: 1000,
            alphaAmount: 900,
            spotPrice: 1_000_000_000
        )

        let validator = setup.factory.priceImpactAcceptable(
            quote: quote,
            locale: locale
        )

        assertWarningContinued(run(validator))

        verify(setup.presentable).presentHighPriceImpact(any(), impact: any(), action: any(), locale: any())
    }

    func testPriceImpactExactlyAtWarningThresholdPasses() {
        let setup = makeSetup()

        let quote = makeStakeQuote(
            taoAmount: 1000,
            alphaAmount: 990,
            spotPrice: 1_000_000_000
        )

        let validator = setup.factory.priceImpactAcceptable(
            quote: quote,
            locale: locale
        )

        assertCompleted(run(validator))
    }

    func testPriceImpactJustAboveWarningThresholdWarns() {
        let setup = makeSetup()

        stub(setup.presentable) { stub in
            when(
                stub.presentHighPriceImpact(any(), impact: any(), action: any(), locale: any())
            ).then { (_, _, action: @escaping () -> Void, _) in
                action()
            }
        }

        let quote = makeStakeQuote(
            taoAmount: 1000,
            alphaAmount: 989,
            spotPrice: 1_000_000_000
        )

        let validator = setup.factory.priceImpactAcceptable(
            quote: quote,
            locale: locale
        )

        assertWarningContinued(run(validator))
    }
}
