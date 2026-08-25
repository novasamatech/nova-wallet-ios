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

    private func makeSetup() -> Setup {
        let presentable = MockSubtensorStakingTestWireframeProtocol()

        let chain = ChainModelGenerator.generateChain(
            generatingAssets: 1,
            addressPrefix: 42,
            assetPresicion: 9,
            hasStaking: true
        )

        let factory = SubtensorStakingValidationFactory(
            presentable: presentable,
            assetDisplayInfo: chain.utilityAsset()!.displayInfo,
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
            amount: BigUInt(2_000_100),
            minStake: BigUInt(2_000_000),
            quotedSwapFee: BigUInt(100),
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
            amount: BigUInt(1_999_999),
            minStake: BigUInt(2_000_000),
            quotedSwapFee: nil,
            locale: locale
        )

        assertError(run(validator))

        verify(setup.presentable).presentStakeAmountTooLow(any(), minStake: any(), locale: any())
    }

    func testRetainsFeeReserveAfterStakePassesWithHeadroom() {
        let setup = makeSetup()

        let validator = setup.factory.retainsFeeReserveAfterStake(
            balance: BigUInt(1_000_000_000),
            amount: BigUInt(100_000_000),
            fee: BigUInt(1_000_000),
            existentialDeposit: BigUInt(500),
            locale: locale
        )

        assertCompleted(run(validator))
    }

    func testRetainsFeeReserveAfterStakeWarnsWithoutHeadroom() {
        let setup = makeSetup()

        stub(setup.presentable) { stub in
            when(
                stub.presentStakeAllWarning(any(), reserve: any(), action: any(), locale: any())
            ).then { (_, _, action: @escaping () -> Void, _) in
                action()
            }
        }

        let validator = setup.factory.retainsFeeReserveAfterStake(
            balance: BigUInt(101_000_000),
            amount: BigUInt(100_000_000),
            fee: BigUInt(1_000_000),
            existentialDeposit: BigUInt(500),
            locale: locale
        )

        assertWarningContinued(run(validator))
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

    func testSubnetStakingEnabledPassesOnRootWithoutSubtoken() {
        let setup = makeSetup()

        let validator = setup.factory.subnetStakingEnabled(
            netuid: 0,
            subnetExists: true,
            subtokenEnabled: false,
            locale: locale
        )

        assertCompleted(run(validator))
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
            locale: locale
        )

        assertWarningContinued(run(validator))
    }

    func testUnstakeNotExceedsAvailablePassesAtAvailable() {
        let setup = makeSetup()

        let validator = setup.factory.unstakeNotExceedsAvailable(
            amount: BigUInt(1_000_000),
            available: BigUInt(1_000_000),
            locale: locale
        )

        assertCompleted(run(validator))
    }

    func testUnstakeNotExceedsAvailableBlocksAboveAvailable() {
        let setup = makeSetup()

        stub(setup.presentable) { stub in
            when(stub.presentUnstakeExceedsAvailable(any(), available: any(), locale: any())).thenDoNothing()
        }

        let validator = setup.factory.unstakeNotExceedsAvailable(
            amount: BigUInt(1_000_001),
            available: BigUInt(1_000_000),
            locale: locale
        )

        assertError(run(validator))

        verify(setup.presentable).presentUnstakeExceedsAvailable(any(), available: any(), locale: any())
    }

    func testUnstakeAboveMinTaoOutPassesForFullUnstake() {
        let setup = makeSetup()

        let validator = setup.factory.unstakeAboveMinTaoOut(
            taoOut: BigUInt(100),
            minAmount: BigUInt(2_000_000),
            isFullUnstake: true,
            locale: locale
        )

        assertCompleted(run(validator))
    }

    func testUnstakeAboveMinTaoOutBlocksBelowMinimum() {
        let setup = makeSetup()

        stub(setup.presentable) { stub in
            when(stub.presentUnstakeAmountTooLow(any(), minAmount: any(), locale: any())).thenDoNothing()
        }

        let validator = setup.factory.unstakeAboveMinTaoOut(
            taoOut: BigUInt(1_999_999),
            minAmount: BigUInt(2_000_000),
            isFullUnstake: false,
            locale: locale
        )

        assertError(run(validator))

        verify(setup.presentable).presentUnstakeAmountTooLow(any(), minAmount: any(), locale: any())
    }

    func testRemainderNotBelowNominatorMinPassesForFullUnstake() {
        let setup = makeSetup()

        let validator = setup.factory.remainderNotBelowNominatorMin(
            remainder: BigUInt(0),
            nominatorMinStake: BigUInt(20_000_000),
            locale: locale
        )

        assertCompleted(run(validator))
    }

    func testRemainderNotBelowNominatorMinWarnsOnDust() {
        let setup = makeSetup()

        stub(setup.presentable) { stub in
            when(
                stub.presentDustRemainderWarning(
                    any(),
                    remainder: any(),
                    minStake: any(),
                    action: any(),
                    locale: any()
                )
            ).then { (_, _, _, action: @escaping () -> Void, _) in
                action()
            }
        }

        let validator = setup.factory.remainderNotBelowNominatorMin(
            remainder: BigUInt(1_000_000),
            nominatorMinStake: BigUInt(20_000_000),
            locale: locale
        )

        assertWarningContinued(run(validator))
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

    func testClaimFirstAdvisoryPassesBelowThreshold() {
        let setup = makeSetup()

        let validator = setup.factory.claimFirstAdvisory(
            claimable: BigUInt(400_000),
            threshold: BigUInt(500_000),
            locale: locale
        )

        assertCompleted(run(validator))
    }

    func testClaimFirstAdvisoryWarnsAtThreshold() {
        let setup = makeSetup()

        stub(setup.presentable) { stub in
            when(
                stub.presentClaimFirstAdvisory(any(), action: any(), locale: any())
            ).then { (_, action: @escaping () -> Void, _) in
                action()
            }
        }

        let validator = setup.factory.claimFirstAdvisory(
            claimable: BigUInt(500_000),
            threshold: BigUInt(500_000),
            locale: locale
        )

        assertWarningContinued(run(validator))
    }

    func testClaimFeeCoveredByTransferablePasses() {
        let setup = makeSetup()

        let validator = setup.factory.claimFeeCoveredByTransferable(
            transferable: BigUInt(100),
            fee: BigUInt(100),
            locale: locale
        )

        assertCompleted(run(validator))
    }

    func testClaimFeeCoveredByTransferableBlocksWhenShort() {
        let setup = makeSetup()

        stub(setup.presentable) { stub in
            when(stub.presentClaimFeeNotAvailable(any(), fee: any(), locale: any())).thenDoNothing()
        }

        let validator = setup.factory.claimFeeCoveredByTransferable(
            transferable: BigUInt(99),
            fee: BigUInt(100),
            locale: locale
        )

        assertError(run(validator))

        verify(setup.presentable).presentClaimFeeNotAvailable(any(), fee: any(), locale: any())
    }

    func testClaimableAtLeastThresholdPasses() {
        let setup = makeSetup()

        let validator = setup.factory.claimableAtLeastThreshold(
            claimable: BigUInt(600_000),
            threshold: BigUInt(500_000),
            locale: locale
        )

        assertCompleted(run(validator))
    }

    func testClaimableAtLeastThresholdBlocksBelowThreshold() {
        let setup = makeSetup()

        stub(setup.presentable) { stub in
            when(stub.presentClaimBelowThreshold(any(), threshold: any(), locale: any())).thenDoNothing()
        }

        let validator = setup.factory.claimableAtLeastThreshold(
            claimable: BigUInt(400_000),
            threshold: BigUInt(500_000),
            locale: locale
        )

        assertError(run(validator))

        verify(setup.presentable).presentClaimBelowThreshold(any(), threshold: any(), locale: any())
    }

    func testClaimableAtLeastThresholdBlocksWhenZero() {
        let setup = makeSetup()

        stub(setup.presentable) { stub in
            when(stub.presentClaimBelowThreshold(any(), threshold: any(), locale: any())).thenDoNothing()
        }

        let validator = setup.factory.claimableAtLeastThreshold(
            claimable: BigUInt(0),
            threshold: BigUInt(500_000),
            locale: locale
        )

        assertError(run(validator))
    }

    func testHasPreflightPassesWhenLoaded() {
        let setup = makeSetup()

        let preflight = SubtensorStakingPreflight(
            hotkeyExists: true,
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

    func testHasMinStakeAmountBlocksWhenMinStakeMissing() {
        let setup = makeSetup()

        stub(setup.presentable) { stub in
            when(stub.presentStakeAmountTooLow(any(), minStake: any(), locale: any())).thenDoNothing()
        }

        let validator = setup.factory.hasMinStakeAmount(
            amount: BigUInt(5_000_000),
            minStake: nil,
            quotedSwapFee: nil,
            locale: locale
        )

        assertError(run(validator))
    }

    func testRetainsFeeReserveAfterStakePassesWhenInputsMissing() {
        let setup = makeSetup()

        let validator = setup.factory.retainsFeeReserveAfterStake(
            balance: nil,
            amount: nil,
            fee: nil,
            existentialDeposit: nil,
            locale: locale
        )

        assertCompleted(run(validator))
    }

    func testUnstakeNotExceedsAvailableBlocksWhenAvailableMissing() {
        let setup = makeSetup()

        stub(setup.presentable) { stub in
            when(stub.presentUnstakeExceedsAvailable(any(), available: any(), locale: any())).thenDoNothing()
        }

        let validator = setup.factory.unstakeNotExceedsAvailable(
            amount: BigUInt(1_000_000),
            available: nil,
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

    func testClaimFirstAdvisoryWarnsWithDefaultThresholdWhenUnavailable() {
        let setup = makeSetup()

        stub(setup.presentable) { stub in
            when(
                stub.presentClaimFirstAdvisory(any(), action: any(), locale: any())
            ).then { (_, action: @escaping () -> Void, _) in
                action()
            }
        }

        let validator = setup.factory.claimFirstAdvisory(
            claimable: BigUInt(600_000),
            threshold: nil,
            locale: locale
        )

        assertWarningContinued(run(validator))
    }
}
