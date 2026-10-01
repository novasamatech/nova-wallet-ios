import BigInt
import Cuckoo
import Foundation_iOS
@testable import novawallet
import XCTest

final class SubtensorUnstakeSetupPresenterTests: XCTestCase {
    private let primaryHotkey = Data(repeating: 0x22, count: 32)
    private let secondHotkey = Data(repeating: 0x33, count: 32)
    private let subnetNetuid: UInt16 = 1
    private let spotPrice: Balance = 73_800_000

    private struct Setup {
        let presenter: SubtensorUnstakeSetupPresenter
        let wireframe: MockSubtensorUnstakeSetupWireframeProtocol
        let interactor: MockSubtensorUnstakeInteractorInputProtocol
        let view: MockSubtensorUnstakeSetupViewProtocol
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

    private func makeFee() -> ExtrinsicFee {
        ExtrinsicFee(amount: 1_000_000, payer: nil, weight: .init(refTime: 1000, proofSize: 0))
    }

    private func makeSubnetsInfo(subnets: [UInt16]) -> SubtensorSubnetsInfo {
        let infos = subnets.map { netuid in
            SubtensorStakingPallet.DynamicInfo(
                netuid: netuid,
                ownerHotkey: Data(repeating: 0, count: 32),
                ownerColdkey: Data(repeating: 0, count: 32),
                subnetName: Data("Chutes".utf8),
                tokenSymbol: Data("ش".utf8),
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
            )
        }

        return SubtensorSubnetsInfo(
            subnets: infos,
            prices: Dictionary(uniqueKeysWithValues: subnets.map { ($0, spotPrice) }),
            subtokenEnabled: Set(subnets),
            ownerCut: 11796
        )
    }

    private func makeSellQuote(alpha: Balance, taoOut: Balance) throws -> SubtensorTradeQuote {
        let quote = SubtensorQuote(
            args: SubtensorQuoteArgs(netuid: subnetNetuid, direction: .unstake(alphaIn: alpha)),
            sim: SubtensorStakingPallet.SimSwapResult(
                taoAmount: taoOut,
                alphaAmount: alpha,
                taoFee: 0,
                alphaFee: 0,
                taoSlippage: 0,
                alphaSlippage: 0
            ),
            spotPrice: spotPrice,
            feeRate: 33
        )

        let limitPrice = try SubtensorLimitPriceCalculator.sellLimit(
            spot: spotPrice,
            tolerance: SubtensorSlippageTolerance.defaultTolerance
        )

        return SubtensorTradeQuote(
            quote: quote,
            amountIn: alpha,
            novaFee: nil,
            expectedOut: taoOut,
            swapMinimumOut: taoOut,
            minimumOut: taoOut,
            limitPrice: limitPrice
        )
    }

    private func makeSetup(
        netuid: UInt16,
        positions: [SubtensorStakingPosition],
        availability: [UInt16: SubtensorStakingPallet.StakeAvailability] = [:],
        free: Balance = 10_000_000_000
    ) -> Setup {
        let chainAsset = makeChainAsset()
        let interactor = MockSubtensorUnstakeInteractorInputProtocol()

        stub(interactor) { stub in
            when(stub.setup()).thenDoNothing()
            when(stub.estimateFee(for: any())).thenDoNothing()
            when(stub.refreshPreflight(for: any(), netuid: any())).thenDoNothing()
            when(stub.refreshQuote(for: any())).thenDoNothing()
            when(stub.refreshPositions()).thenDoNothing()
            when(stub.loadSubnetsInfo(forcingRefresh: any())).thenDoNothing()
            when(stub.loadCatalogue(forcingRefresh: any())).thenDoNothing()
            when(stub.loadSubnetLogos()).thenDoNothing()
            when(stub.loadValidator(any(), on: any())).thenDoNothing()
            when(stub.loadRootHolds(for: any())).thenDoNothing()
            when(stub.loadCostBasis(for: any())).thenDoNothing()
        }

        let wireframe = MockSubtensorUnstakeSetupWireframeProtocol()
        let view = MockSubtensorUnstakeSetupViewProtocol()

        stub(view) { stub in
            when(stub.didReceiveAmount(inputViewModel: any())).thenDoNothing()
            when(stub.didReceiveAmountAsset(viewModel: any())).thenDoNothing()
            when(stub.didReceive(viewModel: any())).thenDoNothing()
        }

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())

        let dataValidationFactory = SubtensorStakingValidationFactory(
            presentable: wireframe,
            assetDisplayInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let presenter = SubtensorUnstakeSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            netuid: netuid,
            chainAsset: chainAsset,
            selectedAccount: makeSelectedAccount(for: chainAsset),
            slippage: SubtensorSlippageTolerance.defaultTolerance,
            dataValidationFactory: dataValidationFactory,
            viewModelFactory: SubtensorUnstakeSetupViewModelFactory(
                chainAsset: chainAsset,
                balanceViewModelFactory: BalanceViewModelFactory(
                    targetAssetInfo: chainAsset.assetDisplayInfo,
                    priceAssetInfoFactory: priceAssetInfoFactory
                ),
                quoteViewModelFactory: SubtensorQuoteViewModelFactory(
                    chainAsset: chainAsset,
                    priceAssetInfoFactory: priceAssetInfoFactory
                )
            ),
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        presenter.view = view
        dataValidationFactory.view = view

        presenter.setup()
        presenter.didReceivePositions(
            Multistaking.SubtensorStakingState(positions: positions, prices: [:], availability: availability)
        )
        presenter.didReceiveAssetBalance(makeBalance(for: chainAsset, free: free))
        presenter.didReceivePreflight(makePreflight())
        presenter.didReceiveExistentialDeposit(500)

        return Setup(presenter: presenter, wireframe: wireframe, interactor: interactor, view: view)
    }

    private func makeRootGroupSetup() -> Setup {
        makeSetup(
            netuid: SubtensorStakingPallet.rootNetuid,
            positions: [
                makePosition(hotkey: secondHotkey, netuid: SubtensorStakingPallet.rootNetuid, stake: 5_000_000_000),
                makePosition(hotkey: primaryHotkey, netuid: SubtensorStakingPallet.rootNetuid, stake: 15_000_000_000)
            ]
        )
    }

    private func proceedAndCaptureModel(_ setup: Setup) -> SubtensorUnstakeConfirmModel? {
        let captor = ArgumentCaptor<SubtensorUnstakeConfirmModel>()

        stub(setup.wireframe) { stub in
            when(stub.showConfirm(from: any(), model: any())).thenDoNothing()
        }

        setup.presenter.didReceiveFee(makeFee())
        setup.presenter.proceed()

        verify(setup.wireframe).showConfirm(from: any(), model: captor.capture())

        return captor.value
    }

    private func makeAmountText(_ value: Decimal) -> String {
        BalanceViewModelFactory(
            targetAssetInfo: makeChainAsset().assetDisplayInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())
        ).amountFromValue(value).value(for: LocalizationManager.shared.selectedLocale)
    }

    private func lastViewModel(_ setup: Setup) throws -> SubtensorUnstakeSetupViewModel {
        let captor = ArgumentCaptor<SubtensorUnstakeSetupViewModel>()

        verify(setup.view, atLeastOnce()).didReceive(viewModel: captor.capture())

        return try XCTUnwrap(captor.allValues.last)
    }

    private func makeQuotedSaleSetup() throws -> Setup {
        let setup = makeSetup(
            netuid: subnetNetuid,
            positions: [makePosition(hotkey: primaryHotkey, netuid: subnetNetuid, stake: 70_200_000_000)]
        )

        setup.presenter.didReceiveSubnetsInfo(makeSubnetsInfo(subnets: [subnetNetuid]))
        setup.presenter.updateAmount(Decimal(string: "56.2"))
        setup.presenter.didReceiveQuote(try makeSellQuote(alpha: 56_200_000_000, taoOut: 4_150_000_000))

        return setup
    }

    private func makeValue(
        _ amount: String,
        detail: String? = nil,
        tone: SubtensorValueTone = .neutral
    ) -> SubtensorCostBasisRowViewModel {
        .value(SubtensorCostBasisValueViewModel(amount: amount, detail: detail, tone: tone))
    }

    func testUnstakeAllOverTwoRootValidatorsExitsBothOfThemWithTheGroupTotal() {
        let setup = makeRootGroupSetup()

        setup.presenter.selectMax()

        let model = proceedAndCaptureModel(setup)

        XCTAssertEqual(model?.origin, .unstake)
        XCTAssertEqual(model?.unstakeModel.hotkey, primaryHotkey)
        XCTAssertEqual(model?.unstakeModel.amount, 20_000_000_000)
        XCTAssertEqual(model?.unstakeModel.exitHotkeys, [primaryHotkey, secondHotkey])
    }

    func testTypedAmountAboveTheValidatorCapIsNotClampedAndRaisesTheExceedsAvailableAlert() {
        let setup = makeRootGroupSetup()

        stub(setup.wireframe) { stub in
            when(stub.showConfirm(from: any(), model: any())).thenDoNothing()
            when(stub.presentUnstakeExceedsAvailable(any(), available: any(), locale: any())).thenDoNothing()
        }

        setup.presenter.updateAmount(Decimal(17))
        setup.presenter.didReceiveFee(makeFee())
        setup.presenter.proceed()

        let expectedCap = makeAmountText(15)

        verify(setup.wireframe).presentUnstakeExceedsAvailable(any(), available: equal(to: expectedCap), locale: any())
        verify(setup.wireframe, never()).showConfirm(from: any(), model: any())
        verify(setup.view, times(1)).didReceiveAmount(inputViewModel: any())
    }

    func testTypedAmountWithinTheCapIsAPartialOnTheLargestValidator() {
        let setup = makeRootGroupSetup()

        setup.presenter.updateAmount(Decimal(10))

        let model = proceedAndCaptureModel(setup)

        XCTAssertEqual(model?.unstakeModel.hotkey, primaryHotkey)
        XCTAssertEqual(model?.unstakeModel.amount, 10_000_000_000)
        XCTAssertNil(model?.unstakeModel.exitHotkeys)
    }

    func testUnstakeAllWithAnotherRootValidatorOnHoldFillsOnlyTheLargestValidator() {
        let setup = makeRootGroupSetup()

        setup.presenter.didReceiveRootHolds([secondHotkey: SubtensorRootHold(interval: 100, lastStakeBlock: 950)])
        setup.presenter.didReceiveBlockNumber(1000)
        setup.presenter.selectMax()

        let model = proceedAndCaptureModel(setup)

        XCTAssertEqual(model?.unstakeModel.hotkey, primaryHotkey)
        XCTAssertEqual(model?.unstakeModel.amount, 15_000_000_000)
        XCTAssertNil(model?.unstakeModel.exitHotkeys)
    }

    func testTypedGroupTotalWithAnotherRootValidatorOnHoldIsAPartialThatRaisesTheExceedsAvailableAlert() {
        let setup = makeRootGroupSetup()

        stub(setup.wireframe) { stub in
            when(stub.showConfirm(from: any(), model: any())).thenDoNothing()
            when(stub.presentUnstakeExceedsAvailable(any(), available: any(), locale: any())).thenDoNothing()
        }

        setup.presenter.didReceiveRootHolds([secondHotkey: SubtensorRootHold(interval: 100, lastStakeBlock: 950)])
        setup.presenter.didReceiveBlockNumber(1000)
        setup.presenter.updateAmount(Decimal(20))
        setup.presenter.didReceiveFee(makeFee())
        setup.presenter.proceed()

        let expectedCap = makeAmountText(15)

        verify(setup.wireframe).presentUnstakeExceedsAvailable(any(), available: equal(to: expectedCap), locale: any())
        verify(setup.wireframe, never()).showConfirm(from: any(), model: any())
    }

    func testActiveHoldOnTheLargestRootValidatorShowsTheBannerAndDisablesContinue() throws {
        let setup = makeRootGroupSetup()

        setup.presenter.didReceiveRootHolds([primaryHotkey: SubtensorRootHold(interval: 100, lastStakeBlock: 950)])
        setup.presenter.didReceiveBlockNumber(1000)
        setup.presenter.updateAmount(Decimal(10))

        let viewModel = try lastViewModel(setup)

        XCTAssertNotNil(viewModel.holdWarning)
        XCTAssertFalse(viewModel.action.isEnabled)
    }

    func testFailedPositionsSyncShowsTheStalePositionsAlertAndNeverOpensTheConfirm() {
        let setup = makeRootGroupSetup()

        stub(setup.wireframe) { stub in
            when(stub.showConfirm(from: any(), model: any())).thenDoNothing()
            when(stub.presentStalePositions(any(), onRetry: any(), locale: any())).thenDoNothing()
        }

        setup.presenter.didReceivePositionsSyncFailed(true)
        setup.presenter.updateAmount(Decimal(10))
        setup.presenter.didReceiveFee(makeFee())
        setup.presenter.proceed()

        verify(setup.wireframe).presentStalePositions(any(), onRetry: any(), locale: any())
        verify(setup.wireframe, never()).showConfirm(from: any(), model: any())
    }

    func testSellMaxOverALockedPositionIsAPartialOfTheAvailableAmountWithTheFreshQuote() throws {
        let setup = makeSetup(
            netuid: subnetNetuid,
            positions: [makePosition(hotkey: primaryHotkey, netuid: subnetNetuid, stake: 70_200_000_000)],
            availability: [
                subnetNetuid: SubtensorStakingPallet.StakeAvailability(
                    total: 70_200_000_000,
                    locked: 14_000_000_000,
                    available: 56_200_000_000
                )
            ]
        )

        let quote = try makeSellQuote(alpha: 56_200_000_000, taoOut: 4_145_000_000)

        setup.presenter.didReceiveSubnetsInfo(makeSubnetsInfo(subnets: [subnetNetuid]))
        setup.presenter.selectMax()
        setup.presenter.didReceiveQuote(quote)

        let model = proceedAndCaptureModel(setup)

        XCTAssertEqual(model?.origin, .sell)
        XCTAssertEqual(model?.unstakeModel.hotkey, primaryHotkey)
        XCTAssertEqual(model?.unstakeModel.amount, 56_200_000_000)
        XCTAssertNil(model?.unstakeModel.exitHotkeys)
        XCTAssertEqual(model?.acknowledgedQuote, quote)
        XCTAssertEqual(model?.tolerance, SubtensorSlippageTolerance.defaultTolerance)
    }

    func testSellWithoutFreeTaoForTheNetworkFeeIsRefusedBeforeTheConfirm() throws {
        let setup = makeSetup(
            netuid: subnetNetuid,
            positions: [makePosition(hotkey: primaryHotkey, netuid: subnetNetuid, stake: 10_000_000_000)],
            free: 1_000_000
        )

        stub(setup.wireframe) { stub in
            when(stub.showConfirm(from: any(), model: any())).thenDoNothing()
            when(stub.presentBatchedSellFeeNotCovered(any(), requiredAmount: any(), locale: any())).thenDoNothing()
        }

        setup.presenter.didReceiveSubnetsInfo(makeSubnetsInfo(subnets: [subnetNetuid]))
        setup.presenter.updateAmount(Decimal(5))
        setup.presenter.didReceiveQuote(try makeSellQuote(alpha: 5_000_000_000, taoOut: 368_900_000))
        setup.presenter.didReceiveFee(makeFee())
        setup.presenter.proceed()

        verify(setup.wireframe).presentBatchedSellFeeNotCovered(any(), requiredAmount: any(), locale: any())
        verify(setup.wireframe, never()).showConfirm(from: any(), model: any())
    }

    func testSellWithoutAQuoteShowsTheQuoteMissingAlertAndNeverOpensTheConfirm() {
        let setup = makeSetup(
            netuid: subnetNetuid,
            positions: [makePosition(hotkey: primaryHotkey, netuid: subnetNetuid, stake: 10_000_000_000)]
        )

        stub(setup.wireframe) { stub in
            when(stub.showConfirm(from: any(), model: any())).thenDoNothing()
            when(stub.presentQuoteMissing(any(), onRetry: any(), locale: any())).thenDoNothing()
        }

        setup.presenter.didReceiveSubnetsInfo(makeSubnetsInfo(subnets: [subnetNetuid]))
        setup.presenter.updateAmount(Decimal(5))
        setup.presenter.didReceiveFee(makeFee())
        setup.presenter.proceed()

        verify(setup.wireframe).presentQuoteMissing(any(), onRetry: any(), locale: any())
        verify(setup.wireframe, never()).showConfirm(from: any(), model: any())
    }

    func testSellShowsTheAverageBuyPriceAndWhatTheQuotedSaleEarnsOverIt() throws {
        let setup = try makeQuotedSaleSetup()

        setup.presenter.didReceivePrice(PriceData(identifier: "bittensor", price: "20", dayChange: nil, currencyId: nil))
        setup.presenter.didReceiveCostBasis(
            .average(SubtensorPurchaseTotals(paidTao: 5_000_000_000, receivedAlpha: 80_000_000_000))
        )

        let details = try lastViewModel(setup).details

        verify(setup.interactor).loadCostBasis(for: equal(to: subnetNetuid))
        XCTAssertEqual(details.avgBuyPrice, makeValue("0.0625 TAO", detail: "per SN1"))
        XCTAssertEqual(details.earned, makeValue("+0.6375 TAO", detail: "≈ $12.75", tone: .positive))
    }

    func testSellWithoutPurchasesShowsTheAverageAsNotAvailableAndNothingEarned() throws {
        let setup = try makeQuotedSaleSetup()

        setup.presenter.didReceiveCostBasis(.noPurchases)

        let details = try lastViewModel(setup).details

        XCTAssertEqual(details.avgBuyPrice, makeValue("Not available", detail: "no purchases"))
        XCTAssertEqual(details.earned, makeValue("—"))
    }

    func testSellKeepsTheCostBasisLoadingUntilTheHistoryAnswersAndShowsDashesWhenItFails() throws {
        let setup = try makeQuotedSaleSetup()

        let loading = try lastViewModel(setup).details

        setup.presenter.didReceiveCostBasis(nil)

        let failed = try lastViewModel(setup).details

        XCTAssertEqual(loading.avgBuyPrice, .loading)
        XCTAssertEqual(loading.earned, .loading)
        XCTAssertEqual(failed.avgBuyPrice, makeValue("—"))
        XCTAssertEqual(failed.earned, makeValue("—"))
    }

    func testRootUnstakeNeverLoadsTheCostBasisAndHidesItsRows() throws {
        let setup = makeRootGroupSetup()

        let details = try lastViewModel(setup).details

        verify(setup.interactor, never()).loadCostBasis(for: any())
        XCTAssertEqual(details.avgBuyPrice, .hidden)
        XCTAssertEqual(details.earned, .hidden)
    }

    func testSubnetMissingFromTheChainCatalogueRefetchesOnceThenOffersRetry() {
        let setup = makeSetup(
            netuid: subnetNetuid,
            positions: [makePosition(hotkey: primaryHotkey, netuid: subnetNetuid, stake: 10_000_000_000)]
        )

        stub(setup.wireframe) { stub in
            when(stub.present(viewModel: any(), style: any(), from: any())).thenDoNothing()
        }

        setup.presenter.didReceiveSubnetsInfo(makeSubnetsInfo(subnets: []))

        verify(setup.interactor, times(1)).loadSubnetsInfo(forcingRefresh: true)
        verify(setup.wireframe, never()).present(viewModel: any(), style: any(), from: any())

        setup.presenter.didReceiveSubnetsInfo(makeSubnetsInfo(subnets: []))

        verify(setup.interactor, times(1)).loadSubnetsInfo(forcingRefresh: true)
        verify(setup.wireframe).present(viewModel: any(), style: any(), from: any())
    }
}
