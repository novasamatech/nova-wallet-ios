import BigInt
import Cuckoo
import Foundation_iOS
@testable import novawallet
import XCTest

final class SubtensorUnstakeConfirmPresenterTests: XCTestCase {
    private let hotkey = Data(repeating: 0x22, count: 32)
    private let unstakeAmount = Balance(1_000_000_000)
    private let networkFee = Balance(1_000_000)

    private let otherHotkey = Data(repeating: 0x33, count: 32)

    private struct Setup {
        let presenter: SubtensorUnstakeConfirmPresenter
        let view: MockSubtensorStakingConfirmViewProtocol
        let wireframe: MockSubtensorUnstakeConfirmWireframeProtocol
        let interactor: MockSubtensorUnstakeConfirmInputProtocol
        let validationView: MockControllerBackedProtocol
        let chainAsset: ChainAsset
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
        taoOut: Balance = 7_670_000,
        spotPrice: Balance
    ) -> SubtensorQuote {
        SubtensorQuote(
            args: SubtensorQuoteArgs(netuid: netuid, direction: .unstake(alphaIn: unstakeAmount)),
            sim: SubtensorStakingPallet.SimSwapResult(
                taoAmount: taoOut,
                alphaAmount: unstakeAmount,
                taoFee: 0,
                alphaFee: 3_300_000,
                taoSlippage: 0,
                alphaSlippage: 0
            ),
            spotPrice: spotPrice,
            feeRate: 33
        )
    }

    private func makeAccount(for chainAsset: ChainAsset) -> MetaChainAccountResponse {
        let accountId = Data(repeating: 0x11, count: 32)

        let chainAccount = ChainAccountResponse(
            metaId: "unstake-confirm-wallet",
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
            metaId: "unstake-confirm-wallet",
            substrateAccountId: accountId,
            ethereumAccountId: nil,
            walletIdenticonData: nil,
            delegationId: nil,
            chainAccount: chainAccount
        )
    }

    private func makeTradeQuote(spotPrice: Balance, taoOut: Balance = 7_670_000) throws -> SubtensorTradeQuote {
        let quote = makeQuote(taoOut: taoOut, spotPrice: spotPrice)
        let limitPrice = try SubtensorLimitPriceCalculator.sellLimit(
            spot: spotPrice,
            tolerance: SubtensorSlippageTolerance.defaultTolerance
        )
        let swappedAlpha = unstakeAmount - quote.sim.alphaFee
        let swapMinimumOut = swappedAlpha * limitPrice / SubtensorStakingPallet.alphaPriceScale

        return SubtensorTradeQuote(
            quote: quote,
            amountIn: unstakeAmount,
            novaFee: nil,
            expectedOut: quote.sim.taoAmount,
            swapMinimumOut: swapMinimumOut,
            minimumOut: swapMinimumOut,
            limitPrice: limitPrice
        )
    }

    private func makePosition(
        hotkey positionHotkey: AccountId,
        netuid: UInt16,
        stakeAlpha: Balance
    ) -> SubtensorStakingPosition {
        SubtensorStakingPosition(
            hotkey: positionHotkey,
            netuid: netuid,
            stakeAlpha: stakeAlpha,
            hotkeyEmissionPerTempo: 0,
            totalHotkeyAlpha: nil,
            isRegistered: true
        )
    }

    private func makePositions(
        hotkeys: [AccountId],
        netuid: UInt16 = SubtensorStakingPallet.rootNetuid
    ) -> Multistaking.SubtensorStakingState {
        Multistaking.SubtensorStakingState(
            positions: hotkeys.map { makePosition(hotkey: $0, netuid: netuid, stakeAlpha: unstakeAmount) },
            prices: [:]
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

    private func makeModel(
        for chainAsset: ChainAsset,
        target: SubtensorStakeTarget,
        tolerance: BigRational?,
        acknowledgedQuote: SubtensorTradeQuote?,
        exitHotkeys: [AccountId]? = nil
    ) -> SubtensorUnstakeConfirmModel {
        let address = (try? hotkey.toAddress(using: chainAsset.chain.chainFormat)) ?? ""

        return SubtensorUnstakeConfirmModel(
            origin: target.isRoot ? .unstake : .sell,
            account: makeAccount(for: chainAsset),
            target: target,
            validator: SubtensorConfirmValidator(
                hotkey: hotkey,
                display: DisplayAddress(address: address, username: ""),
                annualRate: nil
            ),
            unstakeModel: SubtensorUnstakeModel(
                hotkey: hotkey,
                netuid: target.netuid,
                amount: exitHotkeys.map { unstakeAmount * Balance($0.count) } ?? unstakeAmount,
                exitHotkeys: exitHotkeys
            ),
            tolerance: tolerance,
            acknowledgedQuote: acknowledgedQuote
        )
    }

    private func makeSubnetModel(
        for chainAsset: ChainAsset,
        acknowledgedQuote: SubtensorTradeQuote,
        exitHotkeys: [AccountId]? = nil
    ) -> SubtensorUnstakeConfirmModel {
        makeModel(
            for: chainAsset,
            target: makeSubnetTarget(price: acknowledgedQuote.quote.spotPrice),
            tolerance: SubtensorSlippageTolerance.defaultTolerance,
            acknowledgedQuote: acknowledgedQuote,
            exitHotkeys: exitHotkeys
        )
    }

    private func makeSetup(model modelBuilder: (ChainAsset) -> SubtensorUnstakeConfirmModel) -> Setup {
        let chainAsset = makeChainAsset()

        let interactor = MockSubtensorUnstakeConfirmInputProtocol()

        stub(interactor) { stub in
            when(stub.setup()).thenDoNothing()
            when(stub.estimateFee(for: any())).thenDoNothing()
            when(stub.refreshPreflight(for: any(), netuid: any())).thenDoNothing()
            when(stub.refreshQuote(for: any())).thenDoNothing()
            when(stub.refreshPositions()).thenDoNothing()
            when(stub.loadSubnetData()).thenDoNothing()
            when(stub.loadRootHolds(for: any())).thenDoNothing()
            when(stub.loadCostBasis(for: any())).thenDoNothing()
        }

        let wireframe = MockSubtensorUnstakeConfirmWireframeProtocol()

        stub(wireframe) { stub in
            when(stub.showOperationResult(from: any(), request: any(), delegate: any())).thenDoNothing()
            when(stub.present(message: any(), title: any(), closeAction: any(), from: any())).thenDoNothing()
            when(stub.presentStalePositions(any(), onRetry: any(), locale: any())).thenDoNothing()
            when(stub.presentBatchedSellFeeNotCovered(any(), requiredAmount: any(), locale: any())).thenDoNothing()
        }

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())

        let dataValidationFactory = SubtensorStakingValidationFactory(
            presentable: wireframe,
            assetDisplayInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let validationView = MockControllerBackedProtocol()
        dataValidationFactory.view = validationView

        let presenter = SubtensorUnstakeConfirmPresenter(
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

        presenter.didReceiveAssetBalance(makeBalance(for: chainAsset, free: 10_000_000_000))

        presenter.didReceiveFee(
            ExtrinsicFee(amount: networkFee, payer: nil, weight: .init(refTime: 1000, proofSize: 0))
        )

        presenter.didReceivePreflight(makePreflight())
        presenter.didReceiveExistentialDeposit(500)

        return Setup(
            presenter: presenter,
            view: view,
            wireframe: wireframe,
            interactor: interactor,
            validationView: validationView,
            chainAsset: chainAsset
        )
    }

    private func confirmAndCaptureRequest(_ setup: Setup) -> SubtensorOperationResultRequest? {
        let captor = ArgumentCaptor<SubtensorOperationResultRequest>()

        setup.presenter.confirm()

        verify(setup.wireframe).showOperationResult(from: any(), request: captor.capture(), delegate: any())

        return captor.value
    }

    private func lastSwapViewModel(_ setup: Setup) -> SubtensorConfirmSwapViewModel? {
        let captor = ArgumentCaptor<SubtensorConfirmViewModel>()

        verify(setup.view, atLeastOnce()).didReceive(viewModel: captor.capture())

        guard case let .swap(swap)? = captor.allValues.last?.content else {
            return nil
        }

        return swap
    }

    func testRootConfirmHandsOffARootUnstake() {
        let setup = makeSetup { chainAsset in
            makeModel(for: chainAsset, target: .root, tolerance: nil, acknowledgedQuote: nil)
        }

        setup.presenter.didReceivePositions(makePositions(hotkeys: [hotkey]))

        XCTAssertEqual(
            confirmAndCaptureRequest(setup)?.operation,
            .rootUnstake(hotkey: hotkey, amount: unstakeAmount)
        )
        verify(setup.interactor, never()).loadCostBasis(for: any())
    }

    func testSellConfirmShowsTheLossAgainstTheAverageBuyPriceWithTheProfitRemark() throws {
        let acknowledged = try makeTradeQuote(spotPrice: 7_683_255)

        let setup = makeSetup { chainAsset in
            makeSubnetModel(for: chainAsset, acknowledgedQuote: acknowledged)
        }

        setup.presenter.didReceiveCostBasis(
            .average(SubtensorPurchaseTotals(paidTao: 9_000_000, receivedAlpha: 1_000_000_000))
        )

        let swap = try XCTUnwrap(lastSwapViewModel(setup))

        verify(setup.interactor).loadCostBasis(for: equal(to: 1))
        XCTAssertEqual(
            swap.avgBuyPrice,
            .value(SubtensorCostBasisValueViewModel(amount: "0.009 TAO", detail: "per SN1", tone: .neutral))
        )
        XCTAssertEqual(
            swap.youWillEarn,
            .value(SubtensorCostBasisValueViewModel(amount: "\u{2212}0.00133 TAO", detail: nil, tone: .negative))
        )
        XCTAssertEqual(
            swap.remark,
            "Profit is estimated from the average price you paid, before the network fee. " +
                "The rate can change until the order fills."
        )
    }

    func testSellConfirmWithTheHistoryUnavailableShowsDashesAndOnlyTheRateRemark() throws {
        let acknowledged = try makeTradeQuote(spotPrice: 7_683_255)

        let setup = makeSetup { chainAsset in
            makeSubnetModel(for: chainAsset, acknowledgedQuote: acknowledged)
        }

        setup.presenter.didReceiveCostBasis(nil)

        let swap = try XCTUnwrap(lastSwapViewModel(setup))
        let unknown = SubtensorCostBasisRowViewModel.value(
            SubtensorCostBasisValueViewModel(amount: "—", detail: nil, tone: .neutral)
        )

        XCTAssertEqual(swap.avgBuyPrice, unknown)
        XCTAssertEqual(swap.youWillEarn, unknown)
        XCTAssertEqual(swap.remark, "The rate can change until the order fills.")
    }

    func testSellConfirmShowsADashForWhatTheSaleWillEarnWhileTheQuoteFails() throws {
        let acknowledged = try makeTradeQuote(spotPrice: 7_683_255)

        let setup = makeSetup { chainAsset in
            makeSubnetModel(for: chainAsset, acknowledgedQuote: acknowledged)
        }

        setup.presenter.didReceiveCostBasis(
            .average(SubtensorPurchaseTotals(paidTao: 9_000_000, receivedAlpha: 1_000_000_000))
        )
        setup.presenter.didReceiveBaseError(.quoteFailed(SubtensorQuoteError.quoteUnavailable(netuid: 1)))

        let swap = try XCTUnwrap(lastSwapViewModel(setup))

        XCTAssertEqual(
            swap.youWillEarn,
            .value(SubtensorCostBasisValueViewModel(amount: "—", detail: nil, tone: .neutral))
        )
    }

    func testSubnetConfirmSellsAtTheAcknowledgedLimitWithTheLatestTaoOut() throws {
        let acknowledged = try makeTradeQuote(spotPrice: 7_683_255)

        let setup = makeSetup { chainAsset in
            makeSubnetModel(for: chainAsset, acknowledgedQuote: acknowledged)
        }

        setup.presenter.didReceivePositions(makePositions(hotkeys: [hotkey], netuid: 1))
        setup.presenter.didReceiveQuote(try makeTradeQuote(spotPrice: 7_690_000, taoOut: 7_675_000))

        XCTAssertEqual(
            confirmAndCaptureRequest(setup)?.operation,
            .subnetSell(
                hotkey: hotkey,
                netuid: 1,
                alpha: unstakeAmount,
                limitPrice: acknowledged.limitPrice,
                quotedTaoOut: 7_675_000
            )
        )
    }

    func testSellConfirmHandsOffTheCostBasisItShowsToTheResult() throws {
        let acknowledged = try makeTradeQuote(spotPrice: 7_683_255)
        let costBasis = SubtensorCostBasis.average(
            SubtensorPurchaseTotals(paidTao: 9_000_000, receivedAlpha: 1_000_000_000)
        )

        let setup = makeSetup { chainAsset in
            makeSubnetModel(for: chainAsset, acknowledgedQuote: acknowledged)
        }

        setup.presenter.didReceivePositions(makePositions(hotkeys: [hotkey], netuid: 1))
        setup.presenter.didReceiveCostBasis(costBasis)

        XCTAssertEqual(confirmAndCaptureRequest(setup)?.costBasis, .resolved(costBasis))
    }

    func testGroupExitHandsOffTheHotkeysRebuiltFromTheLiveGroupAndEmptiesThePosition() {
        let setup = makeSetup { chainAsset in
            makeModel(
                for: chainAsset,
                target: .root,
                tolerance: nil,
                acknowledgedQuote: nil,
                exitHotkeys: [hotkey, otherHotkey]
            )
        }

        setup.presenter.didReceivePositions(makePositions(hotkeys: [hotkey, otherHotkey]))

        let request = confirmAndCaptureRequest(setup)

        XCTAssertEqual(request?.operation, .rootUnstakeAll(hotkeys: [hotkey, otherHotkey]))
        XCTAssertEqual(request?.emptiesPosition, true)
        XCTAssertEqual(request?.stakeBefore, unstakeAmount * 2)
    }

    func testSubnetGroupExitSellsTheRebuiltHotkeysAtTheAcknowledgedLimitWithTheLatestTaoOut() throws {
        let acknowledged = try makeTradeQuote(spotPrice: 7_683_255)

        let setup = makeSetup { chainAsset in
            makeSubnetModel(for: chainAsset, acknowledgedQuote: acknowledged, exitHotkeys: [hotkey])
        }

        setup.presenter.didReceivePositions(makePositions(hotkeys: [hotkey], netuid: 1))
        setup.presenter.didReceiveQuote(try makeTradeQuote(spotPrice: 7_690_000, taoOut: 7_675_000))

        XCTAssertEqual(
            confirmAndCaptureRequest(setup)?.operation,
            .subnetSellAll(
                hotkeys: [hotkey],
                netuid: 1,
                limitPrice: acknowledged.limitPrice,
                quotedTaoOut: 7_675_000
            )
        )
    }

    func testChangedLiveGroupRefusesTheGroupExitWithoutARetry() {
        let newHotkey = Data(repeating: 0x44, count: 32)

        let setup = makeSetup { chainAsset in
            makeModel(
                for: chainAsset,
                target: .root,
                tolerance: nil,
                acknowledgedQuote: nil,
                exitHotkeys: [hotkey, otherHotkey]
            )
        }

        setup.presenter.didReceivePositions(makePositions(hotkeys: [hotkey, otherHotkey, newHotkey]))
        setup.presenter.confirm()

        verify(setup.wireframe).present(message: any(), title: any(), closeAction: any(), from: any())
        verify(setup.wireframe, never()).presentStalePositions(any(), onRetry: any(), locale: any())
        verify(setup.wireframe, never()).showOperationResult(from: any(), request: any(), delegate: any())
    }

    func testGroupExitWithAZeroAlphaMemberIsNotHandedOff() {
        let setup = makeSetup { chainAsset in
            makeModel(
                for: chainAsset,
                target: .root,
                tolerance: nil,
                acknowledgedQuote: nil,
                exitHotkeys: [hotkey, otherHotkey]
            )
        }

        setup.presenter.didReceivePositions(
            Multistaking.SubtensorStakingState(
                positions: [
                    makePosition(hotkey: hotkey, netuid: SubtensorStakingPallet.rootNetuid, stakeAlpha: unstakeAmount),
                    makePosition(hotkey: otherHotkey, netuid: SubtensorStakingPallet.rootNetuid, stakeAlpha: 0)
                ],
                prices: [:]
            )
        )

        setup.presenter.confirm()

        verify(setup.wireframe, never()).showOperationResult(from: any(), request: any(), delegate: any())
    }

    func testGroupExitBeforePositionsArriveOffersAPositionsRefresh() throws {
        let setup = makeSetup { chainAsset in
            makeModel(
                for: chainAsset,
                target: .root,
                tolerance: nil,
                acknowledgedQuote: nil,
                exitHotkeys: [hotkey]
            )
        }

        var retry: (() -> Void)?

        stub(setup.wireframe) { stub in
            when(
                stub.presentStalePositions(any(), onRetry: any(), locale: any())
            ).then { (_, onRetry: @escaping () -> Void, _) in
                retry = onRetry
            }
        }

        setup.presenter.confirm()

        try XCTUnwrap(retry)()

        verify(setup.interactor).refreshPositions()
        verify(setup.wireframe, never()).showOperationResult(from: any(), request: any(), delegate: any())
    }

    func testSellWithFreeTaoBelowTheNetworkFeePlusTheDepositIsRefused() throws {
        let acknowledged = try makeTradeQuote(spotPrice: 7_683_255)

        let setup = makeSetup { chainAsset in
            makeSubnetModel(for: chainAsset, acknowledgedQuote: acknowledged)
        }

        setup.presenter.didReceivePositions(makePositions(hotkeys: [hotkey], netuid: 1))
        setup.presenter.didReceiveAssetBalance(makeBalance(for: setup.chainAsset, free: networkFee))

        setup.presenter.confirm()

        verify(setup.wireframe).presentBatchedSellFeeNotCovered(any(), requiredAmount: any(), locale: any())
        verify(setup.wireframe, never()).showOperationResult(from: any(), request: any(), delegate: any())
    }

    func testRootUnstakeWithTheFeePaidFromStakeShowsTheStakeAfterNetOfTheFeeAsAnEstimate() {
        let setup = makeSetup { chainAsset in
            makeModel(for: chainAsset, target: .root, tolerance: nil, acknowledgedQuote: nil)
        }

        setup.presenter.didReceivePositions(
            Multistaking.SubtensorStakingState(
                positions: [
                    makePosition(
                        hotkey: hotkey,
                        netuid: SubtensorStakingPallet.rootNetuid,
                        stakeAlpha: 2_000_000_000
                    )
                ],
                prices: [:]
            )
        )

        setup.presenter.didReceiveAssetBalance(makeBalance(for: setup.chainAsset, free: 500_000))

        XCTAssertEqual(
            setup.presenter.createStakeChange(),
            SubtensorConfirmStakeChange(before: 2_000_000_000, after: 999_000_000, isEstimated: true)
        )
    }
}
