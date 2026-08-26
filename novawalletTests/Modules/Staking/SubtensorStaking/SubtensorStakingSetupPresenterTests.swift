import BigInt
import Cuckoo
import Foundation_iOS
@testable import novawallet
import XCTest

final class SubtensorStakingSetupPresenterTests: XCTestCase {
    private let hotkey = Data(repeating: 0x22, count: 32)

    private struct Setup {
        let presenter: SubtensorStakingSetupPresenter
        let wireframe: MockSubtensorStakingSetupWireframeProtocol
        let interactor: MockSubtensorStakingSetupInteractorInputProtocol
        let view: MockSubtensorStakingSetupViewProtocol
    }

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
            enabled: true,
            source: .remote
        )

        let chain = ChainModelGenerator.generateChain(
            assets: [asset],
            defaultChainId: KnowChainId.bittensor,
            addressPrefix: 42
        )

        return ChainAsset(chain: chain, asset: asset)
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
            effectiveNominatorMinStake: 1,
            rootClaimableThreshold: 500_000,
            delegateTake: 11796
        )
    }

    private func makeSubnetTarget(netuid: UInt16 = 1, price: Balance = 7_683_255) -> SubtensorStakeTarget {
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
            price: price
        )
    }

    private func makeQuote(netuid: UInt16 = 1, taoIn: Balance, spotPrice: Balance) -> SubtensorQuote {
        SubtensorQuote(
            args: SubtensorQuoteArgs(netuid: netuid, direction: .stake(taoIn: taoIn)),
            sim: SubtensorStakingPallet.SimSwapResult(
                taoAmount: 999_496_453,
                alphaAmount: 130_082_405_209,
                taoFee: 503_547,
                alphaFee: 0,
                taoSlippage: 0,
                alphaSlippage: 70_762_340
            ),
            spotPrice: spotPrice,
            feeRate: 33
        )
    }

    private func makeView() -> MockSubtensorStakingSetupViewProtocol {
        let view = MockSubtensorStakingSetupViewProtocol()

        stub(view) { stub in
            when(stub.didReceiveAmount(inputViewModel: any())).thenDoNothing()
            when(stub.didReceiveCollator(viewModel: any())).thenDoNothing()
            when(stub.didReceiveAssetBalance(viewModel: any())).thenDoNothing()
            when(stub.didReceiveMinStake(viewModel: any())).thenDoNothing()
            when(stub.didReceiveFee(viewModel: any())).thenDoNothing()
            when(stub.didReceiveStakeTarget(viewModel: any())).thenDoNothing()
            when(stub.didReceiveSlippage(viewModel: any())).thenDoNothing()
            when(stub.didReceiveQuote(viewModel: any())).thenDoNothing()
            when(stub.didReceiveReward(viewModel: any())).thenDoNothing()
            when(stub.didReceiveRewardHidden(any())).thenDoNothing()
        }

        return view
    }

    private func makeEngine(
        annualReturn: Decimal?
    ) -> MockSubtensorRewardCalculatorEngineProtocol {
        let engine = MockSubtensorRewardCalculatorEngineProtocol()

        stub(engine) { stub in
            when(stub.isRootEmissionPaused.get).thenReturn(false)
            when(stub.rootAnnualReturn()).thenReturn(annualReturn)
            when(stub.rootAnnualReturn(take: any())).thenReturn(annualReturn)
        }

        return engine
    }

    private func makeSetup(withPreflight: Bool = true) -> Setup {
        let chainAsset = makeChainAsset()

        let interactor = MockSubtensorStakingSetupInteractorInputProtocol()

        stub(interactor) { stub in
            when(stub.setup()).thenDoNothing()
            when(stub.estimateFee(for: any())).thenDoNothing()
            when(stub.refreshPreflight(for: any(), netuid: any())).thenDoNothing()
            when(stub.refreshQuote(for: any())).thenDoNothing()
            when(stub.applyDelegate(with: any(), netuid: any())).thenDoNothing()
        }

        let wireframe = MockSubtensorStakingSetupWireframeProtocol()

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())

        let dataValidationFactory = SubtensorStakingValidationFactory(
            presentable: wireframe,
            assetDisplayInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let presenter = SubtensorStakingSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chainAsset: chainAsset,
            dataValidationFactory: dataValidationFactory,
            balanceViewModelFactory: BalanceViewModelFactory(
                targetAssetInfo: chainAsset.assetDisplayInfo,
                priceAssetInfoFactory: priceAssetInfoFactory
            ),
            accountDetailsViewModelFactory: CollatorStakingAccountViewModelFactory(chainAsset: chainAsset),
            quoteViewModelFactory: SubtensorQuoteViewModelFactory(chainAsset: chainAsset),
            initialPosition: SubtensorStakingPosition(
                hotkey: hotkey,
                netuid: SubtensorStakingPallet.rootNetuid,
                stakeAlpha: 5_000_000_000,
                hotkeyEmissionPerTempo: 0,
                totalHotkeyAlpha: nil,
                isRegistered: true
            ),
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = makeView()
        presenter.view = view

        let chainAssetId = ChainAssetId(chainId: chainAsset.chain.chainId, assetId: chainAsset.asset.assetId)

        presenter.didReceiveAssetBalance(
            AssetBalance(
                chainAssetId: chainAssetId,
                accountId: Data(repeating: 0x11, count: 32),
                freeInPlank: 10_000_000_000,
                reservedInPlank: 0,
                frozenInPlank: 0,
                edCountMode: .basedOnFree,
                transferrableMode: .fungibleTrait,
                blocked: false
            )
        )

        presenter.didReceiveFee(
            ExtrinsicFee(amount: 1_000_000, payer: nil, weight: .init(refTime: 1000, proofSize: 0))
        )

        if withPreflight {
            presenter.didReceivePreflight(makePreflight())
        }

        presenter.didReceiveExistentialDeposit(500_000)

        return Setup(presenter: presenter, wireframe: wireframe, interactor: interactor, view: view)
    }

    private func proceedAndCaptureModel(_ setup: Setup) -> SubtensorStakingConfirmModel? {
        let captor = ArgumentCaptor<SubtensorStakingConfirmModel>()

        stub(setup.wireframe) { stub in
            when(stub.showConfirmation(from: any(), model: any())).thenDoNothing()
        }

        setup.presenter.didReceiveFee(
            ExtrinsicFee(amount: 1_000_000, payer: nil, weight: .init(refTime: 1000, proofSize: 0))
        )

        setup.presenter.proceed()

        verify(setup.wireframe).showConfirmation(from: any(), model: captor.capture())

        return captor.value
    }

    func testRootProceedProducesModelWithoutLimitPriceOrSlippage() {
        let setup = makeSetup()

        setup.presenter.updateAmount(Decimal(string: "1"))

        let model = proceedAndCaptureModel(setup)

        XCTAssertEqual(model?.stakeModel.netuid, SubtensorStakingPallet.rootNetuid)
        XCTAssertNil(model?.stakeModel.limitPrice)
        XCTAssertNil(model?.slippage)
        XCTAssertEqual(model?.target, .root)
    }

    func testSubnetProceedDerivesLimitFromFreshQuoteSpot() {
        let setup = makeSetup()

        setup.presenter.didSelectStakeTarget(makeSubnetTarget(price: 7_000_000))
        setup.presenter.updateAmount(Decimal(string: "1"))
        setup.presenter.didReceiveQuote(makeQuote(taoIn: 1_000_000_000, spotPrice: 7_683_255))
        setup.presenter.didReceivePreflight(makePreflight())

        let model = proceedAndCaptureModel(setup)

        XCTAssertEqual(model?.stakeModel.netuid, 1)
        XCTAssertEqual(model?.stakeModel.limitPrice, 7_721_671)
        XCTAssertEqual(model?.slippage, SubtensorSlippageTolerance.defaultTolerance)
        XCTAssertEqual(model?.quote?.spotPrice, 7_683_255)
    }

    func testSubnetProceedWithoutQuoteIsBlockedByValidation() {
        let setup = makeSetup()

        setup.presenter.didSelectStakeTarget(makeSubnetTarget(price: 7_000_000))
        setup.presenter.updateAmount(Decimal(string: "1"))
        setup.presenter.didReceivePreflight(makePreflight())

        stub(setup.wireframe) { stub in
            when(stub.showConfirmation(from: any(), model: any())).thenDoNothing()
        }

        setup.presenter.didReceiveFee(
            ExtrinsicFee(amount: 1_000_000, payer: nil, weight: .init(refTime: 1000, proofSize: 0))
        )

        setup.presenter.proceed()

        verify(setup.wireframe, never()).showConfirmation(from: any(), model: any())
    }

    func testRootDelegateRowRendersTheExistingPositionInTheChainSymbol() throws {
        let setup = makeSetup()

        setup.presenter.didReceivePositions(
            makePositions(netuid: SubtensorStakingPallet.rootNetuid)
        )

        let subtitle = try captureDelegateRowSubtitle(setup)

        XCTAssertTrue(subtitle.contains("TAO"))
    }

    func testSubnetDelegateRowRendersTheExistingPositionInTheSubnetSymbol() throws {
        let setup = makeSetup()

        setup.presenter.didSelectStakeTarget(makeSubnetTarget())
        setup.presenter.didReceivePositions(makePositions(netuid: 1))

        let subtitle = try captureDelegateRowSubtitle(setup)

        XCTAssertTrue(subtitle.contains("\u{03B1}"))
        XCTAssertFalse(subtitle.contains("TAO"))
    }

    private func makePositions(netuid: UInt16) -> Multistaking.SubtensorStakingState {
        Multistaking.SubtensorStakingState(
            positions: [
                SubtensorStakingPosition(
                    hotkey: hotkey,
                    netuid: netuid,
                    stakeAlpha: 10_000_000_000,
                    hotkeyEmissionPerTempo: 0,
                    totalHotkeyAlpha: nil,
                    isRegistered: true
                )
            ],
            prices: [:]
        )
    }

    private func captureDelegateRowSubtitle(_ setup: Setup) throws -> String {
        let captor = ArgumentCaptor<AccountDetailsSelectionViewModel?>()

        verify(setup.view, atLeastOnce()).didReceiveCollator(viewModel: captor.capture())

        let viewModel = try XCTUnwrap(captor.allValues.last ?? nil)

        return try XCTUnwrap(viewModel.details?.subtitle)
    }

    func testRootRewardRowUsesTheTakeNettedRate() {
        let setup = makeSetup()
        let engine = makeEngine(annualReturn: Decimal(string: "0.05"))

        setup.presenter.didReceiveRewardEngine(engine)

        verify(engine).rootAnnualReturn(take: equal(to: UInt16(11796)))
        verify(engine, never()).rootAnnualReturn()
        verify(setup.view, atLeastOnce()).didReceiveRewardHidden(false)
    }

    func testRootRewardRowStaysHiddenUntilTheDelegateTakeIsKnown() {
        let setup = makeSetup(withPreflight: false)
        let engine = makeEngine(annualReturn: Decimal(string: "0.05"))

        setup.presenter.didReceiveRewardEngine(engine)

        verify(engine, never()).rootAnnualReturn(take: any())
        verify(setup.view, never()).didReceiveRewardHidden(false)
    }

    func testRewardRowIsHiddenWithoutARewardEngine() {
        let setup = makeSetup()

        setup.presenter.didReceiveRewardEngine(nil)

        verify(setup.view, never()).didReceiveRewardHidden(false)
    }

    func testSubnetTargetHidesTheRewardRow() {
        let setup = makeSetup()

        setup.presenter.didSelectStakeTarget(makeSubnetTarget())
        setup.presenter.didReceivePreflight(makePreflight())
        setup.presenter.didReceiveRewardEngine(makeEngine(annualReturn: Decimal(string: "0.05")))

        verify(setup.view, never()).didReceiveRewardHidden(false)
    }

    func testChangingDelegateHidesTheRewardRowUntilTheNewTakeArrives() {
        let setup = makeSetup()

        setup.presenter.didReceiveRewardEngine(makeEngine(annualReturn: Decimal(string: "0.05")))

        let otherHotkey = Data(repeating: 0x33, count: 32)

        setup.presenter.modalPickerDidSelectModelAtIndex(
            0,
            context: [
                CollatorStakingAccountViewModelFactory.StakedCollator(collator: otherHotkey, amount: 0)
            ] as NSArray
        )

        let captor = ArgumentCaptor<Bool>()

        verify(setup.view, atLeastOnce()).didReceiveRewardHidden(captor.capture())

        XCTAssertEqual(captor.allValues.last, true)
    }

    func testFirstSubnetTapShowsRiskNoteBeforeSelection() {
        let setup = makeSetup()

        stub(setup.wireframe) { stub in
            when(stub.showSubnetRiskNote(from: any(), onContinue: any()))
                .then { _, onContinue in onContinue() }
            when(stub.showSubnetSelection(from: any(), delegate: any(), delegateTake: any()))
                .thenDoNothing()
        }

        setup.presenter.selectStakeTarget()

        verify(setup.wireframe, times(1)).showSubnetRiskNote(from: any(), onContinue: any())
        verify(setup.wireframe, times(1)).showSubnetSelection(
            from: any(),
            delegate: any(),
            delegateTake: any()
        )
    }

    func testRiskNoteAcknowledgementIsNotRepeatedOnSecondTap() {
        let setup = makeSetup()

        stub(setup.wireframe) { stub in
            when(stub.showSubnetRiskNote(from: any(), onContinue: any()))
                .then { _, onContinue in onContinue() }
            when(stub.showSubnetSelection(from: any(), delegate: any(), delegateTake: any()))
                .thenDoNothing()
        }

        setup.presenter.selectStakeTarget()
        setup.presenter.selectStakeTarget()

        verify(setup.wireframe, times(1)).showSubnetRiskNote(from: any(), onContinue: any())
        verify(setup.wireframe, times(2)).showSubnetSelection(
            from: any(),
            delegate: any(),
            delegateTake: any()
        )
    }
}
