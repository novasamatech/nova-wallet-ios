import BigInt
import Cuckoo
import Foundation_iOS
@testable import novawallet
import XCTest

final class SubtensorStakingConfirmPresenterTests: XCTestCase {
    private let hotkey = Data(repeating: 0x22, count: 32)
    private let stakeAmount = Balance(1_000_000_000)

    private struct Setup {
        let presenter: SubtensorStakingConfirmPresenter
        let view: MockSubtensorStakingConfirmViewProtocol
        let wireframe: MockSubtensorStakingConfirmWireframeProtocol
        let interactor: MockSubtensorConfirmInteractorInputProtocol
        let validationView: MockControllerBackedProtocol
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

    private func makeSubnetTarget(netuid: UInt16 = 1, price: Balance = 7_000_000) -> SubtensorStakeTarget {
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

    private func makeQuote(
        netuid: UInt16 = 1,
        spotPrice: Balance,
        alphaAmount: Balance = 130_082_405_209
    ) -> SubtensorQuote {
        SubtensorQuote(
            args: SubtensorQuoteArgs(netuid: netuid, direction: .stake(taoIn: stakeAmount)),
            sim: SubtensorStakingPallet.SimSwapResult(
                taoAmount: 999_496_453,
                alphaAmount: alphaAmount,
                taoFee: 503_547,
                alphaFee: 0,
                taoSlippage: 0,
                alphaSlippage: 70_762_340
            ),
            spotPrice: spotPrice,
            feeRate: 33
        )
    }

    private func makeAccount(
        for chainAsset: ChainAsset,
        type: MetaAccountModelType = .secrets
    ) -> MetaChainAccountResponse {
        let accountId = Data(repeating: 0x11, count: 32)

        let chainAccount = ChainAccountResponse(
            metaId: "confirm-wallet",
            chainId: chainAsset.chain.chainId,
            accountId: accountId,
            publicKey: accountId,
            name: "test",
            cryptoType: .sr25519,
            addressPrefix: chainAsset.chain.addressPrefix,
            isEthereumBased: false,
            isChainAccount: false,
            type: type
        )

        return MetaChainAccountResponse(
            metaId: "confirm-wallet",
            substrateAccountId: accountId,
            ethereumAccountId: nil,
            walletIdenticonData: nil,
            delegationId: nil,
            chainAccount: chainAccount
        )
    }

    private func makeTradeQuote(
        spotPrice: Balance,
        alphaAmount: Balance = 130_082_405_209,
        tolerance: BigRational = SubtensorSlippageTolerance.defaultTolerance
    ) throws -> SubtensorTradeQuote {
        let quote = makeQuote(spotPrice: spotPrice, alphaAmount: alphaAmount)
        let limitPrice = try SubtensorLimitPriceCalculator.buyLimit(spot: spotPrice, tolerance: tolerance)
        let swapMinimumOut = quote.sim.taoAmount * SubtensorStakingPallet.alphaPriceScale / limitPrice

        return SubtensorTradeQuote(
            quote: quote,
            amountIn: stakeAmount,
            novaFee: nil,
            expectedOut: quote.sim.alphaAmount,
            swapMinimumOut: swapMinimumOut,
            minimumOut: swapMinimumOut,
            limitPrice: limitPrice
        )
    }

    private func makeModel(
        for chainAsset: ChainAsset,
        target: SubtensorStakeTarget,
        tolerance: BigRational?,
        acknowledgedQuote: SubtensorTradeQuote?,
        walletType: MetaAccountModelType = .secrets,
        origin: SubtensorOperationOrigin = .newPosition
    ) -> SubtensorStakingConfirmModel {
        let address = (try? hotkey.toAddress(using: chainAsset.chain.chainFormat)) ?? ""

        return SubtensorStakingConfirmModel(
            origin: origin,
            account: makeAccount(for: chainAsset, type: walletType),
            target: target,
            validator: SubtensorConfirmValidator(
                hotkey: hotkey,
                display: DisplayAddress(address: address, username: ""),
                annualRate: nil
            ),
            amount: stakeAmount,
            tolerance: tolerance,
            acknowledgedQuote: acknowledgedQuote
        )
    }

    private func makeSubnetModel(
        for chainAsset: ChainAsset,
        acknowledgedQuote: SubtensorTradeQuote,
        walletType: MetaAccountModelType = .secrets,
        origin: SubtensorOperationOrigin = .newPosition
    ) -> SubtensorStakingConfirmModel {
        makeModel(
            for: chainAsset,
            target: makeSubnetTarget(price: acknowledgedQuote.quote.spotPrice),
            tolerance: SubtensorSlippageTolerance.defaultTolerance,
            acknowledgedQuote: acknowledgedQuote,
            walletType: walletType,
            origin: origin
        )
    }

    private func makeView() -> MockSubtensorStakingConfirmViewProtocol {
        let view = MockSubtensorStakingConfirmViewProtocol()

        stub(view) { stub in
            when(stub.isSetup.get).thenReturn(false)
            when(stub.didReceiveWallet(viewModel: any())).thenDoNothing()
            when(stub.didReceiveAccount(viewModel: any())).thenDoNothing()
            when(stub.didReceiveValidator(viewModel: any())).thenDoNothing()
            when(stub.didReceiveTileIcons(viewModel: any())).thenDoNothing()
            when(stub.didReceive(viewModel: any())).thenDoNothing()
            when(stub.didStartLoading()).thenDoNothing()
            when(stub.didStopLoading()).thenDoNothing()
        }

        return view
    }

    private func makeSetup(model modelBuilder: (ChainAsset) -> SubtensorStakingConfirmModel) -> Setup {
        let chainAsset = makeChainAsset()

        let interactor = MockSubtensorConfirmInteractorInputProtocol()

        stub(interactor) { stub in
            when(stub.setup()).thenDoNothing()
            when(stub.estimateFee(for: any())).thenDoNothing()
            when(stub.refreshPreflight(for: any(), netuid: any())).thenDoNothing()
            when(stub.refreshQuote(for: any())).thenDoNothing()
            when(stub.refreshPositions()).thenDoNothing()
            when(stub.loadSubnetData()).thenDoNothing()
            when(stub.loadCostBasis(for: any())).thenDoNothing()
        }

        let wireframe = MockSubtensorStakingConfirmWireframeProtocol()

        stub(wireframe) { stub in
            when(stub.showOperationResult(from: any(), request: any(), delegate: any())).thenDoNothing()
        }

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())

        let dataValidationFactory = SubtensorStakingValidationFactory(
            presentable: wireframe,
            assetDisplayInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let validationView = MockControllerBackedProtocol()
        dataValidationFactory.view = validationView

        let presenter = SubtensorStakingConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chainAsset: chainAsset,
            model: modelBuilder(chainAsset),
            viewModelFactory: SubtensorConfirmViewModelFactory(
                chainAsset: chainAsset,
                priceAssetInfoFactory: priceAssetInfoFactory
            ),
            dataValidationFactory: dataValidationFactory,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = makeView()
        presenter.view = view

        presenter.setup()

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

        presenter.didReceivePreflight(makePreflight())
        presenter.didReceiveExistentialDeposit(500_000)

        return Setup(
            presenter: presenter,
            view: view,
            wireframe: wireframe,
            interactor: interactor,
            validationView: validationView
        )
    }

    private func confirmAndCaptureRequest(_ setup: Setup) -> SubtensorOperationResultRequest? {
        let captor = ArgumentCaptor<SubtensorOperationResultRequest>()

        setup.presenter.confirm()

        verify(setup.wireframe).showOperationResult(from: any(), request: captor.capture(), delegate: any())

        return captor.value
    }

    private func lastViewModel(of setup: Setup) -> SubtensorConfirmViewModel? {
        let captor = ArgumentCaptor<SubtensorConfirmViewModel>()

        verify(setup.view, atLeastOnce()).didReceive(viewModel: captor.capture())

        return captor.allValues.last
    }

    private func lastAvgBuyPrice(of setup: Setup) -> SubtensorCostBasisRowViewModel? {
        guard case let .swap(swap)? = lastViewModel(of: setup)?.content else {
            return nil
        }

        return swap.avgBuyPrice
    }

    private func newRateTitle() -> String {
        R.string(
            preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages
        ).localizable.stakingSubtensorConfirmNewRate()
    }

    private func watchOnlyHint() -> String {
        R.string(
            preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages
        ).localizable.accountManagementWatchOnlyHint()
    }

    func testRootConfirmHandsOffARootStake() {
        let setup = makeSetup { chainAsset in
            makeModel(for: chainAsset, target: .root, tolerance: nil, acknowledgedQuote: nil)
        }

        XCTAssertEqual(
            confirmAndCaptureRequest(setup)?.operation,
            .rootStake(hotkey: hotkey, amount: stakeAmount)
        )
    }

    func testBuyMoreConfirmShowsTheAverageBuyPriceAfterTheLatestQuote() throws {
        let acknowledged = try makeTradeQuote(spotPrice: 7_683_255)

        let setup = makeSetup { chainAsset in
            makeSubnetModel(for: chainAsset, acknowledgedQuote: acknowledged, origin: .buyMore)
        }

        setup.presenter.didReceiveCostBasis(
            .average(SubtensorPurchaseTotals(paidTao: 9_000_000, receivedAlpha: 1_000_000_000))
        )
        setup.presenter.didReceiveQuote(try makeTradeQuote(spotPrice: 7_683_255, alphaAmount: 100_000_000_000))

        verify(setup.interactor).loadCostBasis(for: equal(to: 1))
        XCTAssertEqual(
            lastAvgBuyPrice(of: setup),
            .value(
                SubtensorCostBasisValueViewModel(
                    amount: "0.00999 TAO",
                    detail: "from 0.009 per SN1",
                    tone: .neutral,
                    trend: .rising
                )
            )
        )
    }

    func testBuyMoreConfirmHandsOffTheCostBasisItShowsToTheResult() throws {
        let acknowledged = try makeTradeQuote(spotPrice: 7_683_255)
        let costBasis = SubtensorCostBasis.average(
            SubtensorPurchaseTotals(paidTao: 9_000_000, receivedAlpha: 1_000_000_000)
        )

        let setup = makeSetup { chainAsset in
            makeSubnetModel(for: chainAsset, acknowledgedQuote: acknowledged, origin: .buyMore)
        }

        setup.presenter.didReceiveCostBasis(costBasis)

        XCTAssertEqual(confirmAndCaptureRequest(setup)?.costBasis, .resolved(costBasis))
    }

    func testNewPositionConfirmNeverLoadsTheCostBasisAndHidesTheAverageBuyPrice() throws {
        let acknowledged = try makeTradeQuote(spotPrice: 7_683_255)

        let setup = makeSetup { chainAsset in
            makeSubnetModel(for: chainAsset, acknowledgedQuote: acknowledged)
        }

        verify(setup.interactor, never()).loadCostBasis(for: any())
        XCTAssertEqual(lastAvgBuyPrice(of: setup), .hidden)
    }

    func testSubnetConfirmHandsOffTheAcknowledgedLimitAfterAFillableRequote() throws {
        let acknowledged = try makeTradeQuote(spotPrice: 7_683_255)
        let requote = try makeTradeQuote(spotPrice: 7_690_000)

        let setup = makeSetup { chainAsset in
            makeSubnetModel(for: chainAsset, acknowledgedQuote: acknowledged)
        }

        setup.presenter.didReceiveQuote(requote)

        let request = confirmAndCaptureRequest(setup)

        XCTAssertEqual(
            request?.operation,
            .subnetBuy(hotkey: hotkey, netuid: 1, grossTao: stakeAmount, limitPrice: acknowledged.limitPrice)
        )
        XCTAssertEqual(request?.quote, requote)
        XCTAssertEqual(lastViewModel(of: setup)?.isPriceMoved, false)
    }

    func testRequoteBeyondTheAcknowledgedLimitShowsThePriceMovedBannerAndTheNewRateAction() throws {
        let acknowledged = try makeTradeQuote(spotPrice: 7_683_255)

        let setup = makeSetup { chainAsset in
            makeSubnetModel(for: chainAsset, acknowledgedQuote: acknowledged)
        }

        setup.presenter.didReceiveQuote(try makeTradeQuote(spotPrice: 7_840_000, alphaAmount: 127_405_000_000))

        let viewModel = lastViewModel(of: setup)

        XCTAssertEqual(viewModel?.isPriceMoved, true)
        XCTAssertEqual(
            viewModel?.action,
            SubtensorConfirmActionViewModel(title: newRateTitle(), isEnabled: true)
        )
    }

    func testConfirmAtTheNewRateHandsOffTheLatestQuoteLimit() throws {
        let acknowledged = try makeTradeQuote(spotPrice: 7_683_255)
        let requote = try makeTradeQuote(spotPrice: 7_840_000, alphaAmount: 127_405_000_000)

        let setup = makeSetup { chainAsset in
            makeSubnetModel(for: chainAsset, acknowledgedQuote: acknowledged)
        }

        setup.presenter.didReceiveQuote(requote)

        XCTAssertEqual(
            confirmAndCaptureRequest(setup)?.operation,
            .subnetBuy(hotkey: hotkey, netuid: 1, grossTao: stakeAmount, limitPrice: requote.limitPrice)
        )
        XCTAssertEqual(lastViewModel(of: setup)?.isPriceMoved, false)
    }

    func testWatchOnlyWalletSeesTheReviewWithConfirmDisabledAndHandsNothingOff() throws {
        let acknowledged = try makeTradeQuote(spotPrice: 7_683_255)

        let setup = makeSetup { chainAsset in
            makeSubnetModel(for: chainAsset, acknowledgedQuote: acknowledged, walletType: .watchOnly)
        }

        setup.presenter.confirm()

        let viewModel = lastViewModel(of: setup)

        XCTAssertEqual(viewModel?.action.isEnabled, false)
        XCTAssertEqual(viewModel?.signingHint, watchOnlyHint())
        verify(setup.wireframe, never()).showOperationResult(from: any(), request: any(), delegate: any())
    }

    func testFailedRequoteAfterThePriceImpactWarningShowsTheQuoteMissingAlertAndBuildsNoRequest() throws {
        let tolerance = BigRational(numerator: 5, denominator: 100)
        let acknowledged = try makeTradeQuote(
            spotPrice: 7_000_000,
            alphaAmount: 140_000_000_000,
            tolerance: tolerance
        )

        let setup = makeSetup { chainAsset in
            makeModel(
                for: chainAsset,
                target: makeSubnetTarget(price: 7_000_000),
                tolerance: tolerance,
                acknowledgedQuote: acknowledged
            )
        }

        var proceedAfterWarning: (() -> Void)?

        stub(setup.wireframe) { stub in
            when(
                stub.presentHighPriceImpact(any(), impact: any(), action: any(), locale: any())
            ).then { (_, _, action: @escaping () -> Void, _) in
                proceedAfterWarning = action
            }

            when(stub.presentQuoteMissing(any(), onRetry: any(), locale: any())).thenDoNothing()
        }

        setup.presenter.confirm()
        setup.presenter.didReceiveBaseError(.quoteFailed(SubtensorStakingOperationError.unprotectedSubnetOrder))

        try XCTUnwrap(proceedAfterWarning)()

        verify(setup.wireframe).presentQuoteMissing(any(), onRetry: any(), locale: any())
        verify(setup.wireframe, never()).showOperationResult(from: any(), request: any(), delegate: any())
    }

    func testPriceMovedDuringThePriceImpactWarningHandsNothingOffAfterAFillableRequote() throws {
        let tolerance = BigRational(numerator: 5, denominator: 100)
        let acknowledged = try makeTradeQuote(
            spotPrice: 7_000_000,
            alphaAmount: 140_000_000_000,
            tolerance: tolerance
        )

        let setup = makeSetup { chainAsset in
            makeModel(
                for: chainAsset,
                target: makeSubnetTarget(price: 7_000_000),
                tolerance: tolerance,
                acknowledgedQuote: acknowledged
            )
        }

        var proceedAfterWarning: (() -> Void)?

        stub(setup.wireframe) { stub in
            when(
                stub.presentHighPriceImpact(any(), impact: any(), action: any(), locale: any())
            ).then { (_, _, action: @escaping () -> Void, _) in
                proceedAfterWarning = action
            }
        }

        setup.presenter.confirm()
        setup.presenter.didReceiveQuote(
            try makeTradeQuote(spotPrice: 7_000_000, alphaAmount: 130_000_000_000, tolerance: tolerance)
        )
        setup.presenter.didReceiveQuote(
            try makeTradeQuote(spotPrice: 7_000_000, alphaAmount: 140_500_000_000, tolerance: tolerance)
        )

        try XCTUnwrap(proceedAfterWarning)()

        XCTAssertEqual(lastViewModel(of: setup)?.isPriceMoved, true)
        verify(setup.wireframe, never()).showOperationResult(from: any(), request: any(), delegate: any())
    }
}
