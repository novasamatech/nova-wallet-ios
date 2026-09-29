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

    private func makeValidator(hotkey: AccountId, netuid: UInt16) -> SubtensorValidatorDirectoryItem {
        SubtensorValidatorDirectoryItem(
            hotkey: hotkey,
            netuid: netuid,
            name: "Nova",
            take: nil,
            reportedStake: nil,
            status: nil,
            isNovaPreferred: true
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
            when(stub.showGetTao(from: any(), chainAsset: any(), assetListObservable: any(), rampHandler: any()))
                .thenDoNothing()
        }

        setup.presenter.getTao()

        verify(setup.wireframe).showGetTao(from: any(), chainAsset: any(), assetListObservable: any(), rampHandler: any())
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
        let setup = makeSetup(mode: .mode(for: position))

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
}
