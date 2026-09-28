import BigInt
import Cuckoo
import Foundation_iOS
@testable import novawallet
import XCTest

final class SubtensorUnstakeSetupPresenterTests: XCTestCase {
    private let hotkey = Data(repeating: 0x22, count: 32)
    private let stakedAmount = Balance(5_000_000_000)

    private struct Setup {
        let presenter: SubtensorUnstakeSetupPresenter
        let wireframe: MockSubtensorUnstakeSetupWireframeProtocol
        let interactor: MockSubtensorUnstakeSetupInteractorInputProtocol
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
        availability: SubtensorStakingPallet.StakeAvailability? = nil
    ) -> SubtensorStakingPreflight {
        SubtensorStakingPreflight(
            hotkeyExists: true,
            subnetExists: true,
            subtokenEnabled: true,
            hasColdkeySwapAnnouncement: false,
            isSafeModeActive: false,
            stakeAvailability: availability,
            rootStakeUnlockInterval: 0,
            lastStakeBlock: nil,
            minStake: 2_000_000,
            effectiveNominatorMinStake: 1,
            rootClaimableThreshold: 500_000,
            delegateTake: 11796
        )
    }

    private func makeAvailability(available: Balance) -> SubtensorStakingPallet.StakeAvailability {
        SubtensorStakingPallet.StakeAvailability(
            total: stakedAmount,
            locked: stakedAmount - available,
            available: available
        )
    }

    private func makeSubnetInfo(netuid: UInt16, tokenSymbol: String) -> SubtensorStakingPallet.DynamicInfo {
        SubtensorStakingPallet.DynamicInfo(
            netuid: netuid,
            ownerHotkey: Data(repeating: 0, count: 32),
            ownerColdkey: Data(repeating: 0, count: 32),
            subnetName: Data("Apex".utf8),
            tokenSymbol: Data(tokenSymbol.utf8),
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

    private func makeSubnetsInfo(
        netuid: UInt16 = 1,
        price: Balance = 7_000_000,
        tokenSymbol: String = "α"
    ) -> SubtensorSubnetsInfo {
        SubtensorSubnetsInfo(
            subnets: [makeSubnetInfo(netuid: netuid, tokenSymbol: tokenSymbol)],
            prices: [netuid: price],
            subtokenEnabled: [netuid],
            ownerCut: 11796
        )
    }

    private func makeUnstakeQuote(
        netuid: UInt16 = 1,
        alphaIn: Balance,
        taoOut: Balance,
        spotPrice: Balance
    ) throws -> SubtensorTradeQuote {
        let quote = SubtensorQuote(
            args: SubtensorQuoteArgs(netuid: netuid, direction: .unstake(alphaIn: alphaIn)),
            sim: SubtensorStakingPallet.SimSwapResult(
                taoAmount: taoOut,
                alphaAmount: alphaIn,
                taoFee: 0,
                alphaFee: 3_300_000,
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
            amountIn: alphaIn,
            novaFee: nil,
            expectedOut: taoOut,
            swapMinimumOut: taoOut,
            minimumOut: taoOut,
            limitPrice: limitPrice
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

    private func makeSetup(netuid: UInt16 = SubtensorStakingPallet.rootNetuid) -> Setup {
        let chainAsset = makeChainAsset()

        let interactor = MockSubtensorUnstakeSetupInteractorInputProtocol()

        stub(interactor) { stub in
            when(stub.setup()).thenDoNothing()
            when(stub.estimateFee(for: any())).thenDoNothing()
            when(stub.refreshPreflight(for: any(), netuid: any())).thenDoNothing()
            when(stub.refreshQuote(for: any())).thenDoNothing()
            when(stub.applyDelegate(with: any(), netuid: any())).thenDoNothing()
        }

        let wireframe = MockSubtensorUnstakeSetupWireframeProtocol()

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())

        let dataValidationFactory = SubtensorStakingValidationFactory(
            presentable: wireframe,
            assetDisplayInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let presenter = SubtensorUnstakeSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chainAsset: chainAsset,
            selectedAccount: makeSelectedAccount(for: chainAsset),
            dataValidationFactory: dataValidationFactory,
            balanceViewModelFactory: BalanceViewModelFactory(
                targetAssetInfo: chainAsset.assetDisplayInfo,
                priceAssetInfoFactory: priceAssetInfoFactory
            ),
            priceAssetInfoFactory: priceAssetInfoFactory,
            accountDetailsViewModelFactory: CollatorStakingAccountViewModelFactory(chainAsset: chainAsset),
            quoteViewModelFactory: SubtensorQuoteViewModelFactory(
                chainAsset: chainAsset,
                priceAssetInfoFactory: priceAssetInfoFactory
            ),
            initialPosition: SubtensorStakingPosition(
                hotkey: hotkey,
                netuid: netuid,
                stakeAlpha: stakedAmount,
                hotkeyEmissionPerTempo: 0,
                totalHotkeyAlpha: nil,
                isRegistered: true
            ),
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let chainAssetId = ChainAssetId(chainId: chainAsset.chain.chainId, assetId: chainAsset.asset.assetId)

        presenter.didReceivePositions(
            Multistaking.SubtensorStakingState(
                positions: [
                    SubtensorStakingPosition(
                        hotkey: hotkey,
                        netuid: netuid,
                        stakeAlpha: stakedAmount,
                        hotkeyEmissionPerTempo: 0,
                        totalHotkeyAlpha: nil,
                        isRegistered: true
                    )
                ],
                prices: [:]
            )
        )

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
        presenter.didReceiveExistentialDeposit(500)

        return Setup(presenter: presenter, wireframe: wireframe, interactor: interactor)
    }

    private func proceedAndCaptureModel(_ setup: Setup) -> SubtensorUnstakeConfirmModel? {
        let captor = ArgumentCaptor<SubtensorUnstakeConfirmModel>()

        stub(setup.wireframe) { stub in
            when(stub.showConfirm(from: any(), model: any())).thenDoNothing()
        }

        setup.presenter.didReceiveFee(
            ExtrinsicFee(amount: 1_000_000, payer: nil, weight: .init(refTime: 1000, proofSize: 0))
        )

        setup.presenter.proceed()

        verify(setup.wireframe).showConfirm(from: any(), model: captor.capture())

        return captor.value
    }

    func testFailedPositionsSyncBlocksTheUnstakeSubmission() {
        let setup = makeSetup()

        stub(setup.wireframe) { stub in
            when(stub.showConfirm(from: any(), model: any())).thenDoNothing()
            when(stub.presentStalePositions(any(), onRetry: any(), locale: any())).thenDoNothing()
        }

        setup.presenter.didReceivePositionsSyncFailed(true)
        setup.presenter.selectAmountPercentage(1.0)
        setup.presenter.proceed()

        verify(setup.wireframe, never()).showConfirm(from: any(), model: any())
    }

    func testRecoveredPositionsSyncStopsBlockingTheUnstakeSubmission() {
        let setup = makeSetup()

        setup.presenter.didReceivePositionsSyncFailed(true)
        setup.presenter.didReceivePositionsSyncFailed(false)
        setup.presenter.selectAmountPercentage(1.0)

        let model = proceedAndCaptureModel(setup)

        XCTAssertEqual(model?.unstakeModel.amount, stakedAmount)
    }

    func testHundredPercentRateProducesFullUnstake() {
        let setup = makeSetup()

        setup.presenter.selectAmountPercentage(1.0)

        let model = proceedAndCaptureModel(setup)

        XCTAssertEqual(model?.unstakeModel.isFullUnstake, true)
    }

    func testMaxOnOneOfSeveralValidatorsHandsOverAPartialOfItsWholeStake() {
        let setup = makeSetup()

        setup.presenter.didReceivePositions(
            Multistaking.SubtensorStakingState(
                positions: [hotkey, Data(repeating: 0x33, count: 32)].map { positionHotkey in
                    SubtensorStakingPosition(
                        hotkey: positionHotkey,
                        netuid: SubtensorStakingPallet.rootNetuid,
                        stakeAlpha: stakedAmount,
                        hotkeyEmissionPerTempo: 0,
                        totalHotkeyAlpha: nil,
                        isRegistered: true
                    )
                },
                prices: [:]
            )
        )

        setup.presenter.selectAmountPercentage(1.0)

        let model = proceedAndCaptureModel(setup)

        XCTAssertEqual(model?.unstakeModel.amount, stakedAmount)
        XCTAssertNil(model?.unstakeModel.exitHotkeys)
    }

    func testExactStakedAbsoluteAmountProducesFullUnstake() {
        let setup = makeSetup()

        setup.presenter.updateAmount(Decimal(string: "5"))

        let model = proceedAndCaptureModel(setup)

        XCTAssertEqual(model?.unstakeModel.isFullUnstake, true)
        XCTAssertEqual(model?.unstakeModel.amount, stakedAmount)
    }

    func testNearMaxAbsoluteAmountKeepsPartialUnstake() {
        let setup = makeSetup()

        setup.presenter.updateAmount(Decimal(string: "4.999999999"))

        let model = proceedAndCaptureModel(setup)

        XCTAssertEqual(model?.unstakeModel.isFullUnstake, false)
        XCTAssertEqual(model?.unstakeModel.amount, stakedAmount - 1)
    }

    func testMaxPercentageUsesAvailabilityRatherThanStakedAmount() {
        let setup = makeSetup()

        setup.presenter.didReceivePreflight(makePreflight(availability: makeAvailability(available: 3_000_000_000)))
        setup.presenter.selectAmountPercentage(1.0)

        let model = proceedAndCaptureModel(setup)

        XCTAssertEqual(model?.unstakeModel.amount, 3_000_000_000)
    }

    func testFullUnstakeIsNotClaimedWhenAvailabilityBelowStakedAmount() {
        let setup = makeSetup()

        setup.presenter.didReceivePreflight(makePreflight(availability: makeAvailability(available: 3_000_000_000)))
        setup.presenter.selectAmountPercentage(1.0)

        let model = proceedAndCaptureModel(setup)

        XCTAssertEqual(model?.unstakeModel.isFullUnstake, false)
    }

    func testRateInputRederivesWhenAvailabilityArrivesLate() {
        let setup = makeSetup()

        setup.presenter.selectAmountPercentage(0.5)
        setup.presenter.didReceivePreflight(makePreflight(availability: makeAvailability(available: 2_000_000_000)))

        let model = proceedAndCaptureModel(setup)

        XCTAssertEqual(model?.unstakeModel.amount, 1_000_000_000)
    }

    func testAbsoluteInputIsPreservedWhenAvailabilityArrivesLate() {
        let setup = makeSetup()

        setup.presenter.updateAmount(Decimal(string: "1.5"))
        setup.presenter.didReceivePreflight(makePreflight(availability: makeAvailability(available: 2_000_000_000)))

        let model = proceedAndCaptureModel(setup)

        XCTAssertEqual(model?.unstakeModel.amount, 1_500_000_000)
    }

    func testZeroAvailabilityLocksTheWholePosition() {
        let setup = makeSetup()

        setup.presenter.didReceivePreflight(makePreflight(availability: makeAvailability(available: 0)))

        XCTAssertTrue(setup.presenter.unstakeBasis.isFullyLocked)
        XCTAssertEqual(setup.presenter.unstakeBasis.locked, stakedAmount)
    }

    func testMissingAvailabilityKeepsTheWholePositionUnstakable() {
        let setup = makeSetup()

        XCTAssertFalse(setup.presenter.unstakeBasis.isFullyLocked)
        XCTAssertEqual(setup.presenter.unstakeBasis.available, stakedAmount)
    }

    func testUnstakeAllOfferSwitchesTheInputToAFullUnstake() throws {
        let setup = makeSetup()

        setup.presenter.updateAmount(Decimal(string: "4.99"))

        let unstakeAll = try XCTUnwrap(setup.presenter.getValidationDependencies().onUnstakeAll)

        unstakeAll()

        let model = proceedAndCaptureModel(setup)

        XCTAssertEqual(model?.unstakeModel.isFullUnstake, true)
        XCTAssertEqual(model?.unstakeModel.amount, stakedAmount)
    }

    func testUnstakeAllIsNotOfferedWhenPartOfThePositionIsLocked() {
        let setup = makeSetup()

        setup.presenter.didReceivePreflight(makePreflight(availability: makeAvailability(available: 3_000_000_000)))
        setup.presenter.updateAmount(Decimal(string: "2.99"))

        XCTAssertNil(setup.presenter.getValidationDependencies().onUnstakeAll)
    }

    func testRootValidationDependenciesCarryTheRootNetuid() {
        XCTAssertEqual(
            makeSetup().presenter.getValidationDependencies().netuid,
            SubtensorStakingPallet.rootNetuid
        )
    }

    func testSubnetValidationDependenciesCarryTheSubnetNetuid() {
        let setup = makeSetup(netuid: 1)

        setup.presenter.didReceiveSubnetsInfo(makeSubnetsInfo())

        XCTAssertEqual(setup.presenter.getValidationDependencies().netuid, 1)
    }

    func testSubnetProceedHandsOverTheFreshQuoteAndItsSellLimit() throws {
        let setup = makeSetup(netuid: 1)
        let quote = try makeUnstakeQuote(alphaIn: 1_000_000_000, taoOut: 7_670_000, spotPrice: 7_683_255)

        setup.presenter.didReceiveSubnetsInfo(makeSubnetsInfo(price: 7_000_000))
        setup.presenter.updateAmount(Decimal(string: "1"))
        setup.presenter.didReceiveQuote(quote)

        let model = proceedAndCaptureModel(setup)

        XCTAssertEqual(model?.origin, .sell)
        XCTAssertEqual(model?.unstakeModel.netuid, 1)
        XCTAssertEqual(model?.tolerance, SubtensorSlippageTolerance.defaultTolerance)
        XCTAssertEqual(model?.acknowledgedQuote, quote)
        XCTAssertEqual(setup.presenter.getValidationDependencies().quoteContext?.acknowledgedLimit, 7_644_839)
    }

    func testSubnetHasNoAcknowledgedLimitWithoutAQuote() {
        let setup = makeSetup(netuid: 1)

        setup.presenter.didReceiveSubnetsInfo(makeSubnetsInfo(price: 7_683_255))
        setup.presenter.updateAmount(Decimal(string: "1"))

        XCTAssertNil(setup.presenter.getValidationDependencies().quoteContext?.acknowledgedLimit)
    }

    func testSubnetProceedWithoutQuoteIsBlockedByValidation() {
        let setup = makeSetup(netuid: 1)

        setup.presenter.didReceiveSubnetsInfo(makeSubnetsInfo(price: 7_683_255))
        setup.presenter.updateAmount(Decimal(string: "1"))

        stub(setup.wireframe) { stub in
            when(stub.showConfirm(from: any(), model: any())).thenDoNothing()
            when(stub.presentQuoteMissing(any(), onRetry: any(), locale: any())).thenDoNothing()
        }

        setup.presenter.proceed()

        verify(setup.wireframe, never()).showConfirm(from: any(), model: any())
    }

    func testRootLaneDenominatesTheDelegateRowInTheChainSymbol() throws {
        let subtitle = try renderDelegateRowSubtitle(makeSetup())

        XCTAssertTrue(subtitle.contains("TAO"))
    }

    func testSubnetLaneDenominatesTheDelegateRowInTheSubnetSymbol() throws {
        let setup = makeSetup(netuid: 1)

        setup.presenter.didReceiveSubnetsInfo(makeSubnetsInfo(tokenSymbol: "\u{03B2}"))

        let subtitle = try renderDelegateRowSubtitle(setup)

        XCTAssertTrue(subtitle.contains("\u{03B2}"))
        XCTAssertFalse(subtitle.contains("TAO"))
    }

    func testSubnetLaneFallsBackToTheNetuidSymbolBeforeSubnetsInfoArrives() throws {
        let subtitle = try renderDelegateRowSubtitle(makeSetup(netuid: 64))

        XCTAssertTrue(subtitle.contains("SN64"))
        XCTAssertFalse(subtitle.contains("TAO"))
    }

    private func renderDelegateRowSubtitle(_ setup: Setup) throws -> String {
        let chainAsset = makeChainAsset()

        let viewModel = CollatorStakingAccountViewModelFactory(chainAsset: chainAsset).createCollator(
            from: DisplayAddress(address: "", username: ""),
            stakedAmount: stakedAmount,
            assetDisplayInfo: setup.presenter.getValidationDependencies().assetDisplayInfo,
            locale: Locale(identifier: "en")
        )

        return try XCTUnwrap(viewModel.details?.subtitle)
    }
}
