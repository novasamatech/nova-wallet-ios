import BigInt
import Cuckoo
import Foundation_iOS
@testable import novawallet
import XCTest

final class SubtensorStakingSetupPresenterTests: XCTestCase {
    private let hotkey = Data(repeating: 0x22, count: 32)
    private let rootRef = SubtensorSubnetRef(netuid: SubtensorStakingPallet.rootNetuid, registeredAt: 0)
    private let recordedPurchases = SubtensorPurchaseTotals(paidTao: 4_949_100_000, receivedAlpha: 70_200_000_000)

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

    private func makeTradeQuote(
        taoIn: Balance,
        spotPrice: Balance,
        alphaAmount: Balance = 130_082_405_209
    ) throws -> SubtensorTradeQuote {
        let quote = SubtensorQuote(
            args: SubtensorQuoteArgs(netuid: 1, direction: .stake(taoIn: taoIn)),
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

    func testQuickPickFreezesTargetSkipsUnsupportedPresetAndPreservesAmountThroughManualChoice() {
        var draws = 0
        let visit = SubtensorQuickPickVisit(order: .poolSize, selector: .init { _ in draws += 1; return 0 })
        let setup = makeSetup(mode: .quickPick(.poolSize), visit: visit)
        setup.presenter.updateAmount(2)
        setup.presenter.didReceiveQuickPickSnapshot(.success(SubtensorQuickPickFixtures.snapshot([.init(1)])), generation: visit.generation)
        setup.presenter.didReceivePositions(Multistaking.SubtensorStakingState(positions: []))
        setup.presenter.didReceivePositionsSyncFailed(false)
        setup.presenter.applyLocalization()
        verify(setup.interactor, never()).presetValidator(on: any(), existingHotkey: any())
        XCTAssertEqual(setup.presenter.validatorState, .none)
        XCTAssertEqual(setup.presenter.inputDecimal(), 2)
        let manual = makeSubnetTarget()
        let validator = makeValidator(hotkey: hotkey, netuid: manual.netuid)
        setup.presenter.didSelectStakeTarget(manual, validator: validator)
        setup.presenter.didReceiveQuickPickSnapshot(.success(SubtensorQuickPickFixtures.snapshot([.init(9)])), generation: visit.generation - 1)
        XCTAssertEqual(setup.presenter.target, manual)
        XCTAssertEqual(setup.presenter.validatorState.validator?.hotkey, hotkey)
        XCTAssertEqual(setup.presenter.inputDecimal(), 2)
        XCTAssertEqual(draws, 1)
    }

    func testQuickPickRetryForcesRefreshAndRootNeverRequestsASnapshot() {
        let visit = SubtensorQuickPickVisit(order: .age, selector: .init { _ in 0 })
        let setup = makeSetup(mode: .quickPick(.age), visit: visit)
        setup.presenter.didReceiveQuickPickSnapshot(.success(SubtensorQuickPickFixtures.snapshot([])), generation: visit.generation)
        setup.presenter.retryQuickPick()
        verify(setup.interactor).loadQuickPickSnapshot(generation: equal(to: 2), forcingRefresh: equal(to: true))
        let root = makeSetup(mode: .rootDetails)
        verify(root.interactor, never()).loadQuickPickSnapshot(generation: any(), forcingRefresh: any())
    }

    func testManualReplacementDuringPendingQuickPickWinsAndKeepsBrowseOrigin() {
        let visit = SubtensorQuickPickVisit(order: .age, selector: .init { _ in XCTFail("Late draw"); return 0 })
        let setup = makeSetup(mode: .quickPick(.age), visit: visit)
        let generation = visit.generation
        setup.presenter.didSelectStakeTarget(makeSubnetTarget(), validator: nil)
        setup.presenter.didReceiveQuickPickSnapshot(.success(SubtensorQuickPickFixtures.snapshot([.init(9)])), generation: generation)
        XCTAssertEqual(setup.presenter.target, makeSubnetTarget())
        XCTAssertEqual(setup.presenter.browseState.sort, .age)
        XCTAssertTrue(setup.presenter.browseState.filters.hideThinPools)
        XCTAssertTrue(visit.isManuallyReplaced)
    }

    func testNoTaoKeepsSelectedSubnetAndValidatorAndDisablesContinue() throws {
        let validator = makeValidator(hotkey: hotkey, netuid: 1)
        let setup = makeSetup(mode: .subnetPick(target: makeSubnetTarget(), validator: validator), free: 0)
        let model = try lastViewModel(setup)
        XCTAssertNotNil(model.getTao)
        XCTAssertFalse(model.action.isEnabled)
        XCTAssertEqual(setup.presenter.validatorState.validator?.hotkey, hotkey)
        XCTAssertEqual(setup.presenter.target, makeSubnetTarget())
        guard case let .subnet(details) = model.details else { return XCTFail("Expected selected subnet") }
        XCTAssertTrue(details.card.chips.isEmpty)
    }

    func testQuickPickRejectsOtherRegistrationMetadataAndDecoratesTheSameDrawWhenMatchingDataArrives() throws {
        var draws = 0
        let visit = SubtensorQuickPickVisit(order: .age, selector: .init { _ in draws += 1; return 0 })
        let setup = makeSetup(mode: .quickPick(.age), visit: visit)
        let snapshot = SubtensorQuickPickFixtures.snapshot([.init(1, registered: 200)])
        let oldCatalogue = makeSetupCatalogue(registered: 100, name: "Retired subnet", symbol: "OLD")
        stub(setup.interactor) { stub in
            when(stub.cachedCatalogue()).thenReturn(.fresh(oldCatalogue, freshUntil: 300))
            when(stub.cachedRankingView()).thenReturn(.fresh(makeSetupRanking(registered: 100), freshUntil: 300))
        }
        setup.presenter.didReceiveQuickPickSnapshot(.success(snapshot), generation: visit.generation)
        let target = try XCTUnwrap(setup.presenter.target)
        let logo = try XCTUnwrap(URL(string: "https://example.test/subnet.png"))
        setup.presenter.didReceiveSubnetLogos(SubtensorSubnetLogos(urls: [1: logo]))
        setup.presenter.didSelectValidator(makeValidator(hotkey: hotkey, netuid: 1), for: target)
        setup.presenter.updateAmount(1)
        setup.presenter.didReceiveQuote(try makeTradeQuote(taoIn: 1_000_000_000, spotPrice: 1_000_000))

        let oldCard = try lastCardViewModel(setup)
        XCTAssertEqual(oldCard.header?.title, "Subnet 1")
        XCTAssertFalse(try XCTUnwrap(oldCard.header).isSelectable)
        XCTAssertTrue(oldCard.header?.icon is StaticImageViewModel)
        XCTAssertTrue(oldCard.chips.isEmpty)
        assertTradeSymbol(oldCard, symbol: "SN1")

        setup.presenter.didReceiveCatalogue(makeSetupCatalogue(registered: 200, name: "Current subnet", symbol: "NEW"))
        setup.presenter.didReceiveRankingView(makeSetupRanking(registered: 200))
        let currentCard = try lastCardViewModel(setup)
        XCTAssertEqual(currentCard.header?.title, "Current subnet NEW")
        XCTAssertTrue(try XCTUnwrap(currentCard.header).isSelectable)
        XCTAssertEqual((currentCard.header?.icon as? RemoteImageViewModel)?.url, logo)
        XCTAssertEqual(currentCard.chips.count, 3)
        assertTradeSymbol(currentCard, symbol: "NEW")

        setup.presenter.didReceiveCatalogue(makeSetupCatalogue(registered: 300, name: "Future subnet", symbol: "NEXT"))
        setup.presenter.didReceiveRankingView(makeSetupRanking(registered: 300))
        let futureCard = try lastCardViewModel(setup)
        XCTAssertEqual(futureCard.header?.title, "Subnet 1")
        XCTAssertTrue(futureCard.header?.icon is StaticImageViewModel)
        XCTAssertTrue(futureCard.chips.isEmpty)
        assertTradeSymbol(futureCard, symbol: "SN1")
        XCTAssertEqual(setup.presenter.target, target)
        XCTAssertEqual(visit.selectedRef, SubtensorSubnetRef(netuid: 1, registeredAt: 200))
        XCTAssertEqual(setup.presenter.validatorState.validator?.hotkey, hotkey)
        XCTAssertEqual(setup.presenter.inputDecimal(), 1)
        XCTAssertEqual(draws, 1)
    }

    func testSetupHidesRankingChipsWithoutVerifiableRegistration() throws {
        let visit = SubtensorQuickPickVisit(order: .poolSize, selector: .init { _ in 0 })
        let setup = makeSetup(mode: .quickPick(.poolSize), visit: visit)
        setup.presenter.didReceiveQuickPickSnapshot(
            .success(SubtensorQuickPickFixtures.snapshot([.init(1, registered: 200)])), generation: visit.generation
        )
        let cases: [(UInt64, UInt64?, [UInt16])] = [
            (2_000_200, nil, []), // Missing age cannot identify a registration.
            (100, 101, []), // Invalid subtraction must not underflow.
            (100, 0, []), // The generation predates the selected registration.
            (200, 0, []), // Equality is still ambiguous because backend clamps negative ages to zero.
            (2_000_200, 2_000_000, [1]), // Carry-over may belong to an older generation.
            (2_000_200, 2_000_100, []), // Older registration.
            (2_000_200, 1_999_900, []) // Newer registration.
        ]
        for (block, age, carried) in cases {
            setup.presenter.didReceiveRankingView(makeSetupRanking(sourceBlock: block, age: age, carried: carried))
            XCTAssertTrue(try lastCardViewModel(setup).chips.isEmpty)
        }
        setup.presenter.didReceiveRankingView(makeSetupRanking(registered: 200))
        XCTAssertEqual(try lastCardViewModel(setup).chips.count, 3)
    }

    func testGatedZeroAgeCannotDecorateSelectedRegistrationButPositiveAgeCan() throws {
        var draws = 0
        let visit = SubtensorQuickPickVisit(order: .age, selector: .init { _ in draws += 1; return 0 })
        let setup = makeSetup(mode: .quickPick(.age), visit: visit)
        setup.presenter.didReceiveQuickPickSnapshot(
            .success(SubtensorQuickPickFixtures.snapshot([.init(1, registered: 200)])), generation: visit.generation
        )
        let target = setup.presenter.target

        // A newer catalogue registration can produce this same zero after backend clamping.
        setup.presenter.didReceiveRankingView(makeSetupRanking(sourceBlock: 200, age: 0, carried: [], status: .gated))
        XCTAssertTrue(try lastCardViewModel(setup).chips.isEmpty)

        // Positive non-carried age remains an exact registration match, even for a gated row.
        setup.presenter.didReceiveRankingView(makeSetupRanking(sourceBlock: 201, age: 1, carried: [], status: .gated))
        XCTAssertEqual(try lastCardViewModel(setup).chips, ["deep pool"])
        XCTAssertEqual(setup.presenter.target, target)
        XCTAssertEqual(visit.selectedRef, SubtensorSubnetRef(netuid: 1, registeredAt: 200))
        XCTAssertEqual(draws, 1)
    }

    private func assertTradeSymbol(_ card: SubtensorPickCardViewModel, symbol: String, file: StaticString = #filePath, line: UInt = #line) {
        for row in [card.receive, card.swapRate] {
            guard case let .value(value) = row else { return XCTFail("Expected quoted row", file: file, line: line) }
            XCTAssertTrue(value.contains(" \(symbol)"), value, file: file, line: line)
            XCTAssertFalse(value.contains("OLD") || value.contains("NEXT"), file: file, line: line)
        }
    }

    private func makeSetupCatalogue(registered: UInt64, name: String, symbol: String) -> SubtensorSubnetCatalogue {
        let stamp = SubtensorBackendStamp(asOf: Date(timeIntervalSince1970: 100), freshness: .fresh)
        let subnet = SubtensorCatalogueSubnet(
            netuid: 1, name: name, symbol: symbol, networkRegisteredAt: registered, tempo: 360,
            ownerColdkey: "", ownerHotkey: "",
            links: SubtensorSubnetLinks(githubRepo: "", subnetContact: "", subnetUrl: "", subnetWebsite: "", discord: "", additional: ""),
            taoReserve: 2_000_000_000_000, alphaReserve: 0, alphaOutstanding: 0, taoPerAlpha: 1_000_000,
            metadataStamp: stamp, pricesStamp: stamp
        )
        return SubtensorSubnetCatalogue(subnets: [subnet])
    }

    private func makeSetupRanking(registered: UInt64) -> SubtensorRankedSubnets {
        makeSetupRanking(sourceBlock: 2_000_200, age: 2_000_200 - registered, carried: [])
    }

    private func makeSetupRanking(sourceBlock: UInt64, age: UInt64?, carried: [UInt16], status: SubtensorRankedSubnet.Status = .scored) -> SubtensorRankedSubnets {
        let score = SubtensorMetricScore(raw: 0.01, normalized: 0, weight: 1, isDerived: false, flags: [])
        let subnet = SubtensorRankedSubnet(
            netuid: 1, subnetName: "Ranked subnet", symbol: "RANK", status: status, isEligible: status == .scored,
            reasons: [], riskClass: status == .scored ? .stable : nil, subnetRisk: status == .scored ? 0 : nil,
            breakdown: status == .scored ? SubtensorSubnetBreakdown(
                volatility: score,
                maxDrawdown: score,
                poolDepth: score,
                age: score,
                emissionStability: score,
                stakeConcentration: score
            ) : nil,
            taoIn: 30000, priceTao: 0.001, ageBlocks: age,
            scoredValidators: status == .scored ? 20 : 0, eligibleValidators: status == .scored ? 20 : 0, flags: []
        )
        let generation = SubtensorRecommendationGeneration(
            id: "identity-test", sourceBlockNumber: sourceBlock, modelVersion: "5.0", ageSeconds: 0,
            receivedAt: 100, isServedFromMemory: false, excludedNetuids: [], carriedOverNetuids: carried, inputFlags: [],
            stamp: SubtensorBackendStamp(asOf: Date(timeIntervalSince1970: 100), freshness: .fresh), isPartial: !carried.isEmpty
        )
        return SubtensorRankedSubnets(
            generation: generation,
            policy: SubtensorRecommendationPolicy(
                classification: .pair,
                requiresIdentity: true,
                requiresPositiveSignal: false,
                insufficientHistory: .neutral
            ),
            items: [subnet]
        )
    }

    private func makeSetup(mode: SubtensorStakingSetupMode, free: Balance = 10_000_000_000, visit: SubtensorQuickPickVisit? = nil, rootPresentation: SubtensorRootEntryPresentation = .standard) -> Setup {
        let chainAsset = makeChainAsset()
        let interactor = MockSubtensorSetupInteractorInputProtocol()

        stub(interactor) { stub in
            when(stub.setup()).thenDoNothing()
            when(stub.loadQuickPickSnapshot(generation: any(), forcingRefresh: any())).thenDoNothing()
            when(stub.cancelQuickPickSnapshot()).thenDoNothing()
            when(stub.cachedCatalogue()).thenReturn(.miss)
            when(stub.cachedRankingView()).thenReturn(.miss)
            when(stub.cachedYields(netuid: any())).thenReturn(.miss)
            when(stub.cachedRootYield()).thenReturn(.miss)
            when(stub.cachedCostBasis(netuid: any())).thenReturn(.miss)
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
            when(stub.loadCostBasis(for: any())).thenDoNothing()
        }

        let wireframe = MockSubtensorStakingSetupWireframeProtocol()
        let view = MockSubtensorStakingSetupViewProtocol()

        stub(view) { stub in
            when(stub.isSetup.get).thenReturn(true)
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
            logger: Logger.shared,
            browseState: SubtensorSubnetBrowseState(order: visit?.order),
            quickPickVisit: visit,
            rootEntryPresentation: rootPresentation
        )

        presenter.view = view
        presenter.setup()
        presenter.didReceiveAssetBalance(makeBalance(for: chainAsset, free: free))
        presenter.didReceiveFee(makeFee(1_000_000))
        presenter.didReceiveExistentialDeposit(500_000)

        return Setup(presenter: presenter, wireframe: wireframe, interactor: interactor, view: view)
    }

    func testRootCarouselPresentationIsDistinctWithoutChangingTransactionMode() throws {
        let standard = makeSetup(mode: .rootDetails)
        let quick = makeSetup(mode: .rootDetails, rootPresentation: .quickPickRoot)
        guard case let .root(standardRoot) = try lastViewModel(standard).details,
              case let .root(quickRoot) = try lastViewModel(quick).details else { return XCTFail("Expected root") }
        XCTAssertFalse(standardRoot.isQuickPick)
        XCTAssertTrue(quickRoot.isQuickPick)
        XCTAssertEqual(standard.presenter.mode, .rootDetails)
        XCTAssertEqual(quick.presenter.mode, .rootDetails)
        XCTAssertEqual(try lastViewModel(quick).title, "Earn with Bittensor")
        quick.presenter.didReceiveRootYield(nil)
        guard case let .root(loaded) = try lastViewModel(quick).details else { return XCTFail("Expected root") }
        XCTAssertEqual(loaded.validator.rate, .hidden)
        XCTAssertNil(loaded.compactRate)
    }

    private func presetRootValidator(_ setup: Setup) {
        setup.presenter.didReceivePositions(Multistaking.SubtensorStakingState(positions: []))
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

    private func makeBuyMoreSetup() -> Setup {
        let setup = makeSetup(mode: .buyMore(position: makePosition(hotkey: hotkey, netuid: 1, stake: 70_200_000_000)))

        setup.presenter.didReceiveSubnet(makeSubnetTarget())

        return setup
    }

    private func lastAvgBuyPrice(_ setup: Setup) throws -> SubtensorCostBasisRowViewModel {
        var avgBuyPrice: SubtensorCostBasisRowViewModel?

        if case let .subnet(details) = try lastViewModel(setup).details {
            avgBuyPrice = details.avgBuyPrice
        }

        return try XCTUnwrap(avgBuyPrice)
    }

    private func makeAvgBuyPrice(
        _ amount: String,
        detail: String? = nil,
        trend: SubtensorAvgBuyPriceTrend? = nil
    ) -> SubtensorCostBasisRowViewModel {
        .value(SubtensorCostBasisValueViewModel(amount: amount, detail: detail, tone: .neutral, trend: trend))
    }

    private func stubNavigation(_ setup: Setup) {
        stub(setup.wireframe) { stub in
            when(stub.showValidatorSelection(from: any(), target: any(), selectedHotkey: any(), delegate: any()))
                .thenDoNothing()
            when(stub.showValidatorInfo(from: any(), target: any(), hotkey: any(), detail: any())).thenDoNothing()
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
                ]
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
        verify(setup.wireframe, never()).showSubnetDetails(from: any(), input: any(), delegate: any())
        verify(setup.wireframe, never()).showSlippageSettings(from: any(), current: any(), completion: any())
    }

    func testBuyMoreShowsTheAverageBuyPriceRisingFromTheRecordedAverageOnceTheAmountIsQuoted() throws {
        let setup = makeBuyMoreSetup()

        setup.presenter.didReceiveCostBasis(.average(recordedPurchases))
        setup.presenter.updateAmount(5)

        let quoting = try lastAvgBuyPrice(setup)

        setup.presenter.didReceiveQuote(
            try makeTradeQuote(taoIn: 5_000_000_000, spotPrice: 7_683_255, alphaAmount: 67_800_000_000)
        )

        verify(setup.interactor).loadCostBasis(for: equal(to: 1))
        XCTAssertEqual(quoting, .loading)
        XCTAssertEqual(
            try lastAvgBuyPrice(setup),
            makeAvgBuyPrice("0.07209 TAO", detail: "from 0.0705 per SN1", trend: .rising)
        )
    }

    func testBuyMoreBelowTheRecordedAverageShowsTheAverageBuyPriceFalling() throws {
        let setup = makeBuyMoreSetup()

        setup.presenter.didReceiveCostBasis(.average(recordedPurchases))
        setup.presenter.updateAmount(5)
        setup.presenter.didReceiveQuote(
            try makeTradeQuote(taoIn: 5_000_000_000, spotPrice: 7_683_255, alphaAmount: 80_000_000_000)
        )

        XCTAssertEqual(
            try lastAvgBuyPrice(setup),
            makeAvgBuyPrice("0.06623 TAO", detail: "from 0.0705 per SN1", trend: .falling)
        )
    }

    func testBuyMoreWithoutAnAmountShowsTheRecordedAverageBuyPrice() throws {
        let setup = makeBuyMoreSetup()

        setup.presenter.didReceiveCostBasis(.average(recordedPurchases))
        setup.presenter.didReceiveQuote(try makeTradeQuote(taoIn: 1_000_000_000, spotPrice: 7_683_255))

        XCTAssertEqual(try lastAvgBuyPrice(setup), makeAvgBuyPrice("0.0705 TAO", detail: "per SN1"))
    }

    func testBuyMoreKeepsTheAverageBuyPriceLoadingUntilTheHistoryAnswersAndShowsADashWhenItFails() throws {
        let setup = makeBuyMoreSetup()

        let loading = try lastAvgBuyPrice(setup)

        setup.presenter.didReceiveCostBasis(nil)

        XCTAssertEqual(loading, .loading)
        XCTAssertEqual(try lastAvgBuyPrice(setup), makeAvgBuyPrice("—"))
    }

    func testBuyMoreWithoutRecordedPurchasesShowsTheAverageBuyPriceAsNotAvailable() throws {
        let setup = makeBuyMoreSetup()

        setup.presenter.didReceiveCostBasis(.noPurchases)

        XCTAssertEqual(try lastAvgBuyPrice(setup), makeAvgBuyPrice("Not available", detail: "no purchases"))
    }

    func testNewSubnetPositionNeverLoadsTheCostBasisAndHidesTheAverageBuyPrice() throws {
        let setup = makeSetup(
            mode: .subnetPick(target: makeSubnetTarget(), validator: makeValidator(hotkey: hotkey, netuid: 1))
        )

        verify(setup.interactor, never()).loadCostBasis(for: any())
        XCTAssertEqual(try lastAvgBuyPrice(setup), .hidden)
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
        verify(setup.wireframe, never()).showSubnetDetails(from: any(), input: any(), delegate: any())
        verify(setup.wireframe, never()).showSlippageSettings(from: any(), current: any(), completion: any())
    }

    func testAddStakeDuringTheRootHoldKeepsContinueEnabledAndHandsOverToConfirmation() throws {
        let position = makePosition(hotkey: hotkey, netuid: SubtensorStakingPallet.rootNetuid, stake: 5000)
        let setup = makeSetup(mode: .addStake(position: position))

        setup.presenter.didReceivePreflight(makePreflight(rootStakeUnlockInterval: 7200, lastStakeBlock: 1000))
        setup.presenter.didReceiveBlockNumber(1100)
        setup.presenter.updateAmount(1)

        XCTAssertTrue(try lastViewModel(setup).action.isEnabled)

        let model = proceedAndCaptureModel(setup)

        XCTAssertEqual(model?.origin, .addStake)
    }
}
