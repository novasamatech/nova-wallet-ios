import BigInt
import Cuckoo
@testable import novawallet
import XCTest

final class SubtensorUnstakePresenterValidatingTests: XCTestCase {
    private struct ValidatingFixture: SubtensorUnstakePresenterValidating {}

    private final class RuleRecorder {
        var names: [String] = []

        func rule(_ name: String) -> DataValidating {
            ErrorConditionViolation(onError: {}, preservesCondition: { [weak self] in
                self?.names.append(name)
                return true
            })
        }
    }

    private struct RealSetup {
        let factory: SubtensorStakingValidationFactory
        let presentable: MockSubtensorStakingTestWireframeProtocol
        let view: MockControllerBackedProtocol
    }

    private let locale = Locale(identifier: "en")
    private let accountId = Data(repeating: 0x11, count: 32)
    private let primaryHotkey = Data(repeating: 0x22, count: 32)
    private let secondHotkey = Data(repeating: 0x33, count: 32)
    private let subnetNetuid: UInt16 = 64

    private func makeRecordingFactory(_ recorder: RuleRecorder) -> MockSubtensorStakingValidationFactoryProtocol {
        let factory = MockSubtensorStakingValidationFactoryProtocol()

        stub(factory) { stub in
            when(stub.positionsAreFresh(syncFailed: any(), locale: any(), onRetry: any()))
                .thenReturn(recorder.rule("positions"))
            when(stub.has(fee: any(), locale: any(), onError: any())).thenReturn(recorder.rule("fee"))
            when(stub.hasPreflight(any(), locale: any(), onRetry: any())).thenReturn(recorder.rule("preflight"))
            when(stub.subnetTradesAvailable(tradesUnavailable: any(), locale: any()))
                .thenReturn(recorder.rule("tradesAvailable"))
            when(stub.hasFreshQuote(any(), locale: any(), onRetry: any())).thenReturn(recorder.rule("freshQuote"))
            when(stub.orderWithinSlippageTolerance(quote: any(), limitPrice: any(), locale: any()))
                .thenReturn(recorder.rule("tolerance"))
            when(stub.canPayFeeFromStakeOtherwiseWarns(transferable: any(), fee: any(), locale: any()))
                .thenReturn(recorder.rule("feeFromStake"))
            when(
                stub.canPayBatchedNetworkFee(
                    transferable: any(),
                    networkFee: any(),
                    existentialDeposit: any(),
                    locale: any()
                )
            ).thenReturn(recorder.rule("batchedFee"))
            when(stub.sellPlanAllows(any(), assetDisplayInfo: any(), onUnstakeAll: any(), locale: any()))
                .thenReturn(recorder.rule("sellPlan"))
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

    private func makeRealSetup() -> RealSetup {
        let presentable = MockSubtensorStakingTestWireframeProtocol()

        let factory = SubtensorStakingValidationFactory(
            presentable: presentable,
            assetDisplayInfo: AssetBalanceDisplayInfo.units(for: 9),
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())
        )

        let view = MockControllerBackedProtocol()
        factory.view = view

        return RealSetup(factory: factory, presentable: presentable, view: view)
    }

    private func makePreflight() -> SubtensorStakingPreflight {
        SubtensorStakingPreflight(
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
    }

    private func makeBalance(transferable: Balance) -> AssetBalance {
        AssetBalance(
            chainAssetId: ChainAssetId(chainId: "bittensor", assetId: 0),
            accountId: accountId,
            freeInPlank: transferable,
            reservedInPlank: 0,
            frozenInPlank: 0,
            edCountMode: .basedOnFree,
            transferrableMode: .fungibleTrait,
            blocked: false
        )
    }

    private func makeFee() -> ExtrinsicFeeProtocol {
        ExtrinsicFee(amount: 1_500_000, payer: nil, weight: .init(refTime: 1000, proofSize: 0))
    }

    private func makeSellQuoteContext() -> SubtensorQuoteValidatingContext {
        let quote = SubtensorQuote(
            args: SubtensorQuoteArgs(netuid: subnetNetuid, direction: .unstake(alphaIn: 56_200_000_000)),
            sim: SubtensorStakingPallet.SimSwapResult(
                taoAmount: 4_145_000_000,
                alphaAmount: 56_171_700_618,
                taoFee: 0,
                alphaFee: 28_299_382,
                taoSlippage: 0,
                alphaSlippage: 0
            ),
            spotPrice: 73_800_000,
            feeRate: 33
        )

        let latestQuote = SubtensorTradeQuote(
            quote: quote,
            amountIn: 56_200_000_000,
            novaFee: SubtensorNovaFee(amount: 34_935_547, beneficiary: Data(repeating: 0xBB, count: 32)),
            expectedOut: 4_110_064_453,
            swapMinimumOut: 4_124_744_148,
            minimumOut: 4_089_808_601,
            limitPrice: 73_431_000
        )

        return SubtensorQuoteValidatingContext(
            latestQuote: latestQuote,
            acknowledgedLimit: 73_431_000,
            tradesUnavailable: false,
            onQuoteRefresh: {}
        )
    }

    private func makeRootDep(
        exitHotkeys: [AccountId]? = nil,
        holds: [AccountId: SubtensorRootHold]? = nil,
        transferable: Balance = 10_000_000_000,
        syncFailed: Bool = false,
        onPositionsRefresh: @escaping () -> Void = {}
    ) -> SubtensorUnstakeValidatingDep {
        SubtensorUnstakeValidatingDep(
            netuid: SubtensorStakingPallet.rootNetuid,
            accountId: accountId,
            amount: 1_000_000_000,
            positionAlpha: 5_000_000_000,
            availability: nil,
            exitHotkeys: exitHotkeys,
            balance: makeBalance(transferable: transferable),
            fee: makeFee(),
            existentialDeposit: 500,
            preflight: makePreflight(),
            holds: holds,
            currentBlock: 100_000,
            blockTime: 12000,
            assetDisplayInfo: AssetBalanceDisplayInfo.units(for: 9),
            syncFailed: syncFailed,
            onFeeRefresh: {},
            onPreflightRefresh: {},
            onPositionsRefresh: onPositionsRefresh,
            onUnstakeAll: nil,
            quoteContext: nil
        )
    }

    private func makeSubnetDep(
        transferable: Balance = 10_000_000_000,
        syncFailed: Bool = false,
        onPositionsRefresh: @escaping () -> Void = {},
        onUnstakeAll: (() -> Void)? = nil
    ) -> SubtensorUnstakeValidatingDep {
        SubtensorUnstakeValidatingDep(
            netuid: subnetNetuid,
            accountId: accountId,
            amount: 56_200_000_000,
            positionAlpha: 100_000_000_000,
            availability: nil,
            exitHotkeys: nil,
            balance: makeBalance(transferable: transferable),
            fee: makeFee(),
            existentialDeposit: 500,
            preflight: makePreflight(),
            holds: nil,
            currentBlock: 100_000,
            blockTime: 12000,
            assetDisplayInfo: AssetBalanceDisplayInfo.units(for: 9),
            syncFailed: syncFailed,
            onFeeRefresh: {},
            onPreflightRefresh: {},
            onPositionsRefresh: onPositionsRefresh,
            onUnstakeAll: onUnstakeAll,
            quoteContext: makeSellQuoteContext()
        )
    }

    private func runRules(for dep: SubtensorUnstakeValidatingDep) -> [String] {
        let recorder = RuleRecorder()

        ValidatingFixture().validateUnstake(
            for: dep,
            dataValidationFactory: makeRecordingFactory(recorder),
            selectedLocale: locale,
            onSuccess: {}
        )

        return recorder.names
    }

    private func runReal(_ dep: SubtensorUnstakeValidatingDep, setup: RealSetup) -> Bool {
        var proceeded = false

        ValidatingFixture().validateUnstake(
            for: dep,
            dataValidationFactory: setup.factory,
            selectedLocale: locale
        ) {
            proceeded = true
        }

        return proceeded
    }

    func testSingleRootUnstakeRulesRunInOrder() {
        XCTAssertEqual(
            runRules(for: makeRootDep()),
            ["positions", "fee", "preflight", "feeFromStake", "sellPlan", "rootHold", "coldkeySwap", "safeMode"]
        )
    }

    func testSubnetSellRulesRunInOrder() {
        XCTAssertEqual(
            runRules(for: makeSubnetDep()),
            [
                "positions",
                "fee",
                "preflight",
                "tradesAvailable",
                "freshQuote",
                "tolerance",
                "batchedFee",
                "sellPlan",
                "coldkeySwap",
                "safeMode",
                "priceImpact"
            ]
        )
    }

    func testRootGroupExitPaysTheBatchedFeeAndChecksEveryMembersHold() {
        let recorder = RuleRecorder()
        let factory = makeRecordingFactory(recorder)

        let dep = makeRootDep(
            exitHotkeys: [primaryHotkey, secondHotkey],
            holds: [
                primaryHotkey: SubtensorRootHold(interval: 7200, lastStakeBlock: 90000),
                secondHotkey: SubtensorRootHold(interval: 7200, lastStakeBlock: 95000)
            ]
        )

        ValidatingFixture().validateUnstake(
            for: dep,
            dataValidationFactory: factory,
            selectedLocale: locale,
            onSuccess: {}
        )

        let lastStakeCaptor = ArgumentCaptor<UInt64?>()

        verify(factory, times(2)).rootUnlockIntervalElapsed(
            currentBlock: any(),
            lastStakeBlock: lastStakeCaptor.capture(),
            unlockInterval: any(),
            blockTime: any(),
            locale: any()
        )

        XCTAssertEqual(
            recorder.names,
            ["positions", "fee", "preflight", "batchedFee", "sellPlan", "rootHold", "rootHold", "coldkeySwap", "safeMode"]
        )
        XCTAssertEqual(lastStakeCaptor.allValues, [90000, 95000])
    }

    func testFailedPositionsSyncBlocksARootUnstake() {
        let setup = makeRealSetup()
        var refreshed = false

        stub(setup.presentable) { stub in
            when(
                stub.presentStalePositions(any(), onRetry: any(), locale: any())
            ).then { (_, onRetry: @escaping () -> Void, _) in
                onRetry()
            }
        }

        let proceeded = runReal(
            makeRootDep(syncFailed: true, onPositionsRefresh: { refreshed = true }),
            setup: setup
        )

        XCTAssertFalse(proceeded)
        XCTAssertTrue(refreshed)
    }

    func testFailedPositionsSyncBlocksASubnetSell() {
        let setup = makeRealSetup()
        var refreshed = false

        stub(setup.presentable) { stub in
            when(
                stub.presentStalePositions(any(), onRetry: any(), locale: any())
            ).then { (_, onRetry: @escaping () -> Void, _) in
                onRetry()
            }
        }

        let proceeded = runReal(
            makeSubnetDep(syncFailed: true, onPositionsRefresh: { refreshed = true }),
            setup: setup
        )

        XCTAssertFalse(proceeded)
        XCTAssertTrue(refreshed)
    }

    func testSubnetSellIsRefusedWhenFreeTaoMissesTheFeePlusDeposit() {
        let setup = makeRealSetup()

        stub(setup.presentable) { stub in
            when(stub.presentBatchedSellFeeNotCovered(any(), requiredAmount: any(), locale: any())).thenDoNothing()
        }

        let proceeded = runReal(makeSubnetDep(transferable: 1_500_499), setup: setup)

        XCTAssertFalse(proceeded)
        verify(setup.presentable).presentBatchedSellFeeNotCovered(any(), requiredAmount: any(), locale: any())
    }

    func testSubnetSellProceedsWhenFreeTaoCoversTheFeePlusDeposit() {
        let setup = makeRealSetup()

        XCTAssertTrue(runReal(makeSubnetDep(transferable: 1_500_500), setup: setup))
    }

    func testSingleRootUnstakeShortOfFreeTaoWarnsAndProceeds() {
        let setup = makeRealSetup()
        var proceedAction: (() -> Void)?
        var proceeded = false

        stub(setup.presentable) { stub in
            when(
                stub.presentFeeFromStakeWarning(any(), fee: any(), action: any(), locale: any())
            ).then { (_, _, action: @escaping () -> Void, _) in
                proceedAction = action
            }
        }

        ValidatingFixture().validateUnstake(
            for: makeRootDep(transferable: 1000),
            dataValidationFactory: setup.factory,
            selectedLocale: locale
        ) {
            proceeded = true
        }

        XCTAssertFalse(proceeded)

        proceedAction?()

        XCTAssertTrue(proceeded)
    }

    func testSellPlanRuleForwardsTheUnstakeAllOffer() {
        let factory = makeRecordingFactory(RuleRecorder())

        _ = ValidatingFixture().createUnstakeValidations(
            for: makeSubnetDep(onUnstakeAll: {}),
            dataValidationFactory: factory,
            selectedLocale: locale
        )

        let captor = ArgumentCaptor<(() -> Void)?>()

        verify(factory).sellPlanAllows(any(), assetDisplayInfo: any(), onUnstakeAll: captor.capture(), locale: any())

        XCTAssertNotNil(captor.value ?? nil)
    }
}
