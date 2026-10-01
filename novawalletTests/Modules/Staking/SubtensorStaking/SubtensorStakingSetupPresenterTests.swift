import BigInt
import Cuckoo
import Foundation_iOS
@testable import novawallet
import XCTest

final class SubtensorStakingSetupPresenterTests: XCTestCase {
    private let hotkey = Data(repeating: 0x22, count: 32)
    private let rootRef = SubtensorSubnetRef(netuid: SubtensorStakingPallet.rootNetuid, registeredAt: 0)

    private struct Setup {
        let presenter: SubtensorStakingSetupPresenter
        let wireframe: MockSubtensorStakingSetupWireframeProtocol
        let interactor: MockSubtensorSetupInteractorInputProtocol
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
            source: .remote
        )

        let chain = ChainModelGenerator.generateChain(
            assets: [asset],
            defaultChainId: KnowChainId.bittensor,
            addressPrefix: 42
        )

        return ChainAsset(chain: chain, asset: asset)
    }

    private func makePreflight(
        rootStakeUnlockInterval: UInt64 = 0,
        lastStakeBlock: UInt64? = nil
    ) -> SubtensorStakingPreflight {
        SubtensorStakingPreflight(
            hotkeyExists: true,
            subnetExists: true,
            subtokenEnabled: true,
            hasColdkeySwapAnnouncement: false,
            isSafeModeActive: false,
            stakeAvailability: nil,
            rootStakeUnlockInterval: rootStakeUnlockInterval,
            lastStakeBlock: lastStakeBlock,
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

    private func makeTradeQuote(taoIn: Balance, spotPrice: Balance) throws -> SubtensorTradeQuote {
        let quote = SubtensorQuote(
            args: SubtensorQuoteArgs(netuid: 1, direction: .stake(taoIn: taoIn)),
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

        let limitPrice = try SubtensorLimitPriceCalculator.buyLimit(
            spot: spotPrice,
            tolerance: SubtensorSlippageTolerance.defaultTolerance
        )

        let swapMinimumOut = quote.sim.taoAmount * SubtensorStakingPallet.alphaPriceScale / limitPrice

        return SubtensorTradeQuote(
            quote: quote,
            amountIn: taoIn,
            novaFee: nil,
            expectedOut: quote.sim.alphaAmount,
            swapMinimumOut: swapMinimumOut,
            minimumOut: swapMinimumOut,
            limitPrice: limitPrice
        )
    }

    private func makeNetOfFeeQuote() throws -> SubtensorTradeQuote {
        let quote = SubtensorQuote(
            args: SubtensorQuoteArgs(netuid: 1, direction: .stake(taoIn: 4_957_858_206)),
            sim: SubtensorStakingPallet.SimSwapResult(
                taoAmount: 4_955_362_724,
                alphaAmount: 67_500_000_000,
                taoFee: 2_495_482,
                alphaFee: 0,
                taoSlippage: 0,
                alphaSlippage: 0
            ),
            spotPrice: 73_450_000,
            feeRate: 33
        )

        let limitPrice = try SubtensorLimitPriceCalculator.buyLimit(
            spot: quote.spotPrice,
            tolerance: SubtensorSlippageTolerance.defaultTolerance
        )

        return SubtensorTradeQuote(
            quote: quote,
            amountIn: 5_000_000_000,
            novaFee: SubtensorNovaFee(amount: 42_141_794, beneficiary: Data(repeating: 0xA4, count: 32)),
            expectedOut: 67_500_000_000,
            swapMinimumOut: 65_580_135_000,
            minimumOut: 65_580_135_000,
            limitPrice: limitPrice
        )
    }

    private func makeValidator(hotkey: AccountId, netuid: UInt16) -> SubtensorValidatorDirectoryItem {
        SubtensorValidatorDirectoryItem(
            hotkey: hotkey,
            netuid: netuid,
            name: "Nova",
            take: nil,
            reportedStake: nil,
            status: nil
        )
    }

    private func makePosition(hotkey: AccountId, netuid: UInt16, stake: Balance) -> SubtensorStakingPosition {
        SubtensorStakingPosition(
            hotkey: hotkey,
            netuid: netuid,
            stakeAlpha: stake,
            hotkeyEmissionPerTempo: 0,
            totalHotkeyAlpha: nil,
            isRegistered: true
        )
    }

    private func makeSelectedAccount(for chainAsset: ChainAsset) -> MetaChainAccountResponse {
        let accountId = Data(repeating: 0x11, count: 32)

        let chainAccount = ChainAccountResponse(
            metaId: UUID().uuidString,
            chainId: chainAsset.chain.chainId,
            accountId: accountId,
            publicKey: accountId,
            name: "test",
            cryptoType: .sr25519,
            addressPrefix: chainAsset.chain.addressPrefix,
            isEthereumBased: false,
            isChainAccount: false,
            type: .secrets
        )

        return MetaChainAccountResponse(
            metaId: UUID().uuidString,
            substrateAccountId: accountId,
            ethereumAccountId: nil,
            walletIdenticonData: nil,
            delegationId: nil,
            chainAccount: chainAccount
        )
    }

    private func makeBalance(for chainAsset: ChainAsset, free: Balance) -> AssetBalance {
        AssetBalance(
            chainAssetId: ChainAssetId(chainId: chainAsset.chain.chainId, assetId: chainAsset.asset.assetId),
            accountId: Data(repeating: 0x11, count: 32),
            freeInPlank: free,
            reservedInPlank: 0,
            frozenInPlank: 0,
            edCountMode: .basedOnFree,
            transferrableMode: .fungibleTrait,
            blocked: false
        )
    }

    private func makeFee(_ amount: Balance) -> ExtrinsicFee {
        ExtrinsicFee(amount: amount, payer: nil, weight: .init(refTime: 1000, proofSize: 0))
    }

    private func makeSetup(mode: SubtensorStakingSetupMode, free: Balance = 10_000_000_000) -> Setup {
        let chainAsset = makeChainAsset()
        let interactor = MockSubtensorSetupInteractorInputProtocol()

        stub(interactor) { stub in
            when(stub.setup()).thenDoNothing()
            when(stub.estimateFee(for: any())).thenDoNothing()
            when(stub.refreshPreflight(for: any(), netuid: any())).thenDoNothing()
            when(stub.refreshQuote(for: any())).thenDoNothing()
            when(stub.presetValidator(on: any(), existingHotkey: any())).thenDoNothing()
            when(stub.loadLockedValidator(any(), on: any())).thenDoNothing()
            when(stub.loadRootYield()).thenDoNothing()
            when(stub.loadSubnet(netuid: any())).thenDoNothing()
            when(stub.loadCatalogue()).thenDoNothing()
            when(stub.loadYields(netuid: any())).thenDoNothing()
            when(stub.loadRankingView()).thenDoNothing()
            when(stub.loadSubnetLogos()).thenDoNothing()
        }

        let wireframe = MockSubtensorStakingSetupWireframeProtocol()
        let view = MockSubtensorStakingSetupViewProtocol()

        stub(view) { stub in
            when(stub.didReceiveAmount(inputViewModel: any())).thenDoNothing()
            when(stub.didReceiveAmountAsset(viewModel: any())).thenDoNothing()
            when(stub.didReceive(viewModel: any())).thenDoNothing()
        }

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let presenter = SubtensorStakingSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            mode: mode,
            chainAsset: chainAsset,
            selectedAccount: makeSelectedAccount(for: chainAsset),
            slippage: SubtensorSlippageTolerance.defaultTolerance,
            dataValidationFactory: SubtensorStakingValidationFactory(
                presentable: wireframe,
                assetDisplayInfo: chainAsset.assetDisplayInfo,
                priceAssetInfoFactory: priceAssetInfoFactory
            ),
            balanceViewModelFactory: balanceViewModelFactory,
            viewModelFactory: SubtensorStakingSetupViewModelFactory(
                chainAsset: chainAsset,
                balanceViewModelFactory: balanceViewModelFactory,
                quoteViewModelFactory: SubtensorQuoteViewModelFactory(
                    chainAsset: chainAsset,
                    priceAssetInfoFactory: priceAssetInfoFactory
                )
            ),
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        presenter.view = view
        presenter.setup()
        presenter.didReceiveAssetBalance(makeBalance(for: chainAsset, free: free))
        presenter.didReceiveFee(makeFee(1_000_000))
        presenter.didReceiveExistentialDeposit(500_000)

        return Setup(presenter: presenter, wireframe: wireframe, interactor: interactor, view: view)
    }

    private func presetRootValidator(_ setup: Setup) {
        setup.presenter.didReceivePositions(Multistaking.SubtensorStakingState(positions: [], prices: [:]))
        setup.presenter.didReceiveValidator(
            makeValidator(hotkey: hotkey, netuid: SubtensorStakingPallet.rootNetuid),
            on: rootRef
        )
        setup.presenter.didReceivePreflight(makePreflight())
    }

    private func proceedAndCaptureModel(_ setup: Setup) -> SubtensorStakingConfirmModel? {
        let captor = ArgumentCaptor<SubtensorStakingConfirmModel>()

        stub(setup.wireframe) { stub in
            when(stub.showConfirmation(from: any(), model: any())).thenDoNothing()
        }

        setup.presenter.proceed()

        verify(setup.wireframe).showConfirmation(from: any(), model: captor.capture())

        return captor.value
    }

    private func lastViewModel(_ setup: Setup) throws -> SubtensorStakingSetupViewModel {
        let captor = ArgumentCaptor<SubtensorStakingSetupViewModel>()

        verify(setup.view, atLeastOnce()).didReceive(viewModel: captor.capture())

        return try XCTUnwrap(captor.allValues.last)
    }

    private func lastCardViewModel(_ setup: Setup) throws -> SubtensorPickCardViewModel {
        var card: SubtensorPickCardViewModel?

        if case let .subnet(details) = try lastViewModel(setup).details {
            card = details.card
        }

        return try XCTUnwrap(card)
    }

    private func stubNavigation(_ setup: Setup) {
        stub(setup.wireframe) { stub in
            when(stub.showValidatorSelection(from: any(), target: any(), selectedHotkey: any(), delegate: any()))
                .thenDoNothing()
            when(stub.showValidatorInfo(from: any(), target: any(), hotkey: any(), detail: any())).thenDoNothing()
            when(stub.showSubnetSelection(from: any(), delegate: any())).thenDoNothing()
            when(stub.showSubnetDetails(from: any(), input: any(), delegate: any())).thenDoNothing()
            when(stub.showSlippageSettings(from: any(), current: any(), completion: any())).thenDoNothing()
        }
    }

    func testMaxKeepsTheFeeReserve() {
        let setup = makeSetup(mode: .rootDetails)

        presetRootValidator(setup)
        setup.presenter.selectMax()

        let model = proceedAndCaptureModel(setup)

        XCTAssertEqual(model?.amount, 9_989_000_000)
        XCTAssertEqual(model?.origin, .newPosition)
        XCTAssertEqual(model?.target, .root)
        XCTAssertEqual(model?.validator.hotkey, hotkey)
        XCTAssertNil(model?.tolerance)
    }

    func testNoTaoStateShowsTheGetTaoCardAndRoutesToGetTao() throws {
        let setup = makeSetup(mode: .rootDetails, free: 11_000_000)

        presetRootValidator(setup)

        let viewModel = try lastViewModel(setup)

        XCTAssertNotNil(viewModel.getTao)
        XCTAssertNotNil(viewModel.caption)
        XCTAssertFalse(viewModel.action.isEnabled)

        stub(setup.wireframe) { stub in
            when(stub.showGetTao(from: any(), chainAsset: any(), rampHandler: any())).thenDoNothing()
        }

        setup.presenter.getTao()

        verify(setup.wireframe).showGetTao(from: any(), chainAsset: any(), rampHandler: any())
    }

    func testAmountAboveMaxShowsTheReserveWarningAndDisablesContinue() throws {
        let setup = makeSetup(mode: .rootDetails)

        presetRootValidator(setup)
        setup.presenter.updateAmount(Decimal(string: "9.99"))

        let viewModel = try lastViewModel(setup)

        XCTAssertNotNil(viewModel.reserveWarning)
        XCTAssertNil(viewModel.getTao)
        XCTAssertFalse(viewModel.action.isEnabled)
    }

    func testRootDetailsPresetsFromTheLargestExistingRootPosition() {
        let setup = makeSetup(mode: .rootDetails)
        let smallerHotkey = Data(repeating: 0x33, count: 32)

        setup.presenter.didReceivePositions(
            Multistaking.SubtensorStakingState(
                positions: [
                    makePosition(hotkey: smallerHotkey, netuid: SubtensorStakingPallet.rootNetuid, stake: 1000),
                    makePosition(hotkey: hotkey, netuid: SubtensorStakingPallet.rootNetuid, stake: 5000),
                    makePosition(hotkey: smallerHotkey, netuid: 1, stake: 9000)
                ],
                prices: [:]
            )
        )

        verify(setup.interactor).presetValidator(on: equal(to: rootRef), existingHotkey: equal(to: hotkey))
    }

    func testRootPositionHandsOverALockedAddStakeWithoutTolerance() {
        let position = makePosition(hotkey: hotkey, netuid: SubtensorStakingPallet.rootNetuid, stake: 5000)
        let setup = makeSetup(mode: .addStake(position: position))

        setup.presenter.didReceivePreflight(makePreflight())
        setup.presenter.updateAmount(Decimal(string: "1"))

        let model = proceedAndCaptureModel(setup)

        XCTAssertEqual(model?.origin, .addStake)
        XCTAssertEqual(model?.target, .root)
        XCTAssertEqual(model?.validator.hotkey, hotkey)
        XCTAssertEqual(model?.amount, 1_000_000_000)
        XCTAssertNil(model?.tolerance)
        verify(setup.interactor, never()).presetValidator(on: any(), existingHotkey: any())
    }

    func testSubnetProceedHandsOverANewPositionWithTheToleranceAndTheQuote() throws {
        let setup = makeSetup(mode: .rootDetails)
        let quote = try makeTradeQuote(taoIn: 1_000_000_000, spotPrice: 7_683_255)

        setup.presenter.didSelectStakeTarget(
            makeSubnetTarget(price: 7_000_000),
            validator: makeValidator(hotkey: hotkey, netuid: 1)
        )
        setup.presenter.didReceiveFee(makeFee(1_000_000))
        setup.presenter.updateAmount(Decimal(string: "1"))
        setup.presenter.didReceiveQuote(quote)
        setup.presenter.didReceivePreflight(makePreflight())

        let model = proceedAndCaptureModel(setup)

        XCTAssertEqual(model?.origin, .newPosition)
        XCTAssertEqual(model?.target.netuid, 1)
        XCTAssertEqual(model?.validator.hotkey, hotkey)
        XCTAssertEqual(model?.tolerance, SubtensorSlippageTolerance.defaultTolerance)
        XCTAssertEqual(model?.acknowledgedQuote, quote)
    }

    func testSubnetProceedHandsOverTheFreshApyOfTheValidator() throws {
        let setup = makeSetup(mode: .rootDetails)
        let stamp = SubtensorBackendStamp(asOf: Date(), freshness: .fresh)

        setup.presenter.didSelectStakeTarget(
            makeSubnetTarget(price: 7_000_000),
            validator: makeValidator(hotkey: hotkey, netuid: 1)
        )
        setup.presenter.didReceiveYields(
            SubtensorAlphaYields(
                netuid: 1,
                yields: [hotkey: SubtensorReportedYield(reportedRate: "12.5", stamp: stamp)],
                stamp: stamp,
                isTruncated: false
            ),
            netuid: 1
        )
        setup.presenter.didReceiveFee(makeFee(1_000_000))
        setup.presenter.updateAmount(Decimal(string: "1"))
        setup.presenter.didReceiveQuote(try makeTradeQuote(taoIn: 1_000_000_000, spotPrice: 7_683_255))
        setup.presenter.didReceivePreflight(makePreflight())

        let model = proceedAndCaptureModel(setup)

        XCTAssertEqual(
            model?.validator.annualRate,
            try XCTUnwrap(Decimal(string: "0.125", locale: Locale(identifier: "en_US_POSIX")))
        )
    }

    func testSubnetProceedWithoutQuoteIsBlockedByValidation() {
        let setup = makeSetup(mode: .rootDetails)

        setup.presenter.didSelectStakeTarget(
            makeSubnetTarget(price: 7_000_000),
            validator: makeValidator(hotkey: hotkey, netuid: 1)
        )
        setup.presenter.didReceiveFee(makeFee(1_000_000))
        setup.presenter.updateAmount(Decimal(string: "1"))
        setup.presenter.didReceivePreflight(makePreflight())

        stub(setup.wireframe) { stub in
            when(stub.showConfirmation(from: any(), model: any())).thenDoNothing()
        }

        setup.presenter.proceed()

        verify(setup.wireframe, never()).showConfirmation(from: any(), model: any())
    }

    func testRootValidatorSelectionOpensTheRootListOnTheCurrentValidator() {
        let setup = makeSetup(mode: .rootDetails)

        presetRootValidator(setup)

        stub(setup.wireframe) { stub in
            when(stub.showValidatorSelection(from: any(), target: any(), selectedHotkey: any(), delegate: any()))
                .thenDoNothing()
        }

        setup.presenter.selectValidator()

        verify(setup.wireframe).showValidatorSelection(
            from: any(),
            target: equal(to: .root),
            selectedHotkey: equal(to: hotkey),
            delegate: any()
        )
    }

    func testSubnetValidatorSelectionOpensThePickedSubnetList() {
        let setup = makeSetup(mode: .rootDetails)
        let subnetTarget = makeSubnetTarget()

        setup.presenter.didSelectStakeTarget(subnetTarget, validator: nil)

        stub(setup.wireframe) { stub in
            when(stub.showValidatorSelection(from: any(), target: any(), selectedHotkey: any(), delegate: any()))
                .thenDoNothing()
        }

        setup.presenter.selectValidator()

        verify(setup.wireframe).showValidatorSelection(
            from: any(),
            target: equal(to: subnetTarget),
            selectedHotkey: any(),
            delegate: any()
        )
    }

    func testYouWillGetShowsTheNetOfFeeQuoteForTheEnteredGrossAmount() throws {
        let setup = makeSetup(
            mode: .subnetPick(target: makeSubnetTarget(), validator: makeValidator(hotkey: hotkey, netuid: 1))
        )

        setup.presenter.updateAmount(5)
        setup.presenter.didReceiveQuote(try makeNetOfFeeQuote())

        verify(setup.interactor).refreshQuote(
            for: equal(
                to: .buy(netuid: 1, grossTao: 5_000_000_000, tolerance: SubtensorSlippageTolerance.defaultTolerance)
            )
        )

        let card = try lastCardViewModel(setup)

        XCTAssertEqual(card.receive, .value("\u{2066}≈ 67.5 SN1\u{2069}"))
        XCTAssertEqual(card.swapRate, .value("\u{2066}1 TAO ≈ 13.5 SN1\u{2069}"))
    }

    func testBuyMoreKeepsTheSubnetAndTheValidatorOfThePosition() throws {
        let position = makePosition(hotkey: hotkey, netuid: 1, stake: 5000)
        let otherHotkey = Data(repeating: 0x33, count: 32)
        let subnetTarget = makeSubnetTarget(price: 7_000_000)
        let setup = makeSetup(mode: .buyMore(position: position))

        stubNavigation(setup)

        setup.presenter.didReceiveSubnet(subnetTarget)
        setup.presenter.didSelectStakeTarget(makeSubnetTarget(netuid: 2), validator: nil)
        setup.presenter.didSelectValidator(makeValidator(hotkey: otherHotkey, netuid: 1), for: subnetTarget)
        setup.presenter.selectValidator()
        setup.presenter.chooseMyself()
        setup.presenter.selectCardHeader()
        setup.presenter.selectSettings()

        setup.presenter.didReceiveFee(makeFee(1_000_000))
        setup.presenter.updateAmount(1)
        setup.presenter.didReceiveQuote(try makeTradeQuote(taoIn: 1_000_000_000, spotPrice: 7_683_255))
        setup.presenter.didReceivePreflight(makePreflight())

        let model = proceedAndCaptureModel(setup)

        XCTAssertEqual(model?.origin, .buyMore)
        XCTAssertEqual(model?.target, subnetTarget)
        XCTAssertEqual(model?.validator.hotkey, hotkey)
        XCTAssertFalse(try lastViewModel(setup).hasSettings)
        verify(setup.interactor, never()).presetValidator(on: any(), existingHotkey: any())
        verify(setup.wireframe, never()).showValidatorSelection(
            from: any(),
            target: any(),
            selectedHotkey: any(),
            delegate: any()
        )
        verify(setup.wireframe, never()).showSubnetSelection(from: any(), delegate: any())
        verify(setup.wireframe, never()).showSubnetDetails(from: any(), input: any(), delegate: any())
        verify(setup.wireframe, never()).showSlippageSettings(from: any(), current: any(), completion: any())
    }

    func testAddStakeKeepsTheRootLaneAndTheValidatorOfThePosition() {
        let position = makePosition(hotkey: hotkey, netuid: SubtensorStakingPallet.rootNetuid, stake: 5000)
        let otherHotkey = Data(repeating: 0x33, count: 32)
        let setup = makeSetup(mode: .addStake(position: position))

        stubNavigation(setup)

        setup.presenter.didSelectStakeTarget(makeSubnetTarget(), validator: makeValidator(hotkey: otherHotkey, netuid: 1))
        setup.presenter.didSelectValidator(
            makeValidator(hotkey: otherHotkey, netuid: SubtensorStakingPallet.rootNetuid),
            for: .root
        )
        setup.presenter.selectValidator()
        setup.presenter.chooseMyself()
        setup.presenter.selectCardHeader()
        setup.presenter.selectSettings()

        setup.presenter.didReceivePreflight(makePreflight())
        setup.presenter.updateAmount(1)

        let model = proceedAndCaptureModel(setup)

        XCTAssertEqual(model?.origin, .addStake)
        XCTAssertEqual(model?.target, .root)
        XCTAssertEqual(model?.validator.hotkey, hotkey)
        verify(setup.wireframe).showValidatorInfo(
            from: any(),
            target: equal(to: .root),
            hotkey: equal(to: hotkey),
            detail: any()
        )
        verify(setup.wireframe, never()).showValidatorSelection(
            from: any(),
            target: any(),
            selectedHotkey: any(),
            delegate: any()
        )
        verify(setup.wireframe, never()).showSubnetSelection(from: any(), delegate: any())
        verify(setup.wireframe, never()).showSubnetDetails(from: any(), input: any(), delegate: any())
        verify(setup.wireframe, never()).showSlippageSettings(from: any(), current: any(), completion: any())
    }

    func testAddStakeDuringTheRootHoldShowsTheLockAndDisablesContinue() throws {
        let position = makePosition(hotkey: hotkey, netuid: SubtensorStakingPallet.rootNetuid, stake: 5000)
        let setup = makeSetup(mode: .addStake(position: position))

        setup.presenter.didReceivePreflight(makePreflight(rootStakeUnlockInterval: 7200, lastStakeBlock: 1000))
        setup.presenter.didReceiveBlockNumber(1100)
        setup.presenter.updateAmount(1)

        let viewModel = try lastViewModel(setup)

        XCTAssertNotNil(viewModel.holdWarning)
        XCTAssertFalse(viewModel.action.isEnabled)

        setup.presenter.didReceiveBlockNumber(8200)

        XCTAssertNil(try lastViewModel(setup).holdWarning)
        XCTAssertTrue(try lastViewModel(setup).action.isEnabled)
    }
}
