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
        let view: MockCollatorStakingConfirmViewProtocol
        let wireframe: MockSubtensorStakingConfirmWireframeProtocol
        let interactor: MockSubtensorStakingConfirmInteractorInputProtocol
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
        acknowledgedQuote: SubtensorTradeQuote?
    ) -> SubtensorStakingConfirmModel {
        let address = (try? hotkey.toAddress(using: chainAsset.chain.chainFormat)) ?? ""

        return SubtensorStakingConfirmModel(
            origin: .newPosition,
            account: makeSelectedAccount(for: chainAsset),
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

    private func makeView() -> MockCollatorStakingConfirmViewProtocol {
        let view = MockCollatorStakingConfirmViewProtocol()

        stub(view) { stub in
            when(stub.isSetup.get).thenReturn(false)
            when(stub.didReceiveAmount(viewModel: any())).thenDoNothing()
            when(stub.didReceiveWallet(viewModel: any())).thenDoNothing()
            when(stub.didReceiveAccount(viewModel: any())).thenDoNothing()
            when(stub.didReceiveFee(viewModel: any())).thenDoNothing()
            when(stub.didReceiveCollator(viewModel: any())).thenDoNothing()
            when(stub.didReceiveHints(viewModel: any())).thenDoNothing()
            when(stub.didStartLoading()).thenDoNothing()
            when(stub.didStopLoading()).thenDoNothing()
        }

        return view
    }

    private func makeSetup(model modelBuilder: (ChainAsset) -> SubtensorStakingConfirmModel) -> Setup {
        let chainAsset = makeChainAsset()

        let interactor = MockSubtensorStakingConfirmInteractorInputProtocol()

        stub(interactor) { stub in
            when(stub.setup()).thenDoNothing()
            when(stub.estimateFee(for: any())).thenDoNothing()
            when(stub.refreshPreflight(for: any(), netuid: any())).thenDoNothing()
            when(stub.refreshQuote(for: any())).thenDoNothing()
            when(stub.submit(operation: any())).thenDoNothing()
        }

        let wireframe = MockSubtensorStakingConfirmWireframeProtocol()

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
            selectedAccount: makeSelectedAccount(for: chainAsset),
            chainAsset: chainAsset,
            model: modelBuilder(chainAsset),
            dataValidationFactory: dataValidationFactory,
            balanceViewModelFactory: BalanceViewModelFactory(
                targetAssetInfo: chainAsset.assetDisplayInfo,
                priceAssetInfoFactory: priceAssetInfoFactory
            ),
            quoteViewModelFactory: SubtensorQuoteViewModelFactory(
                chainAsset: chainAsset,
                priceAssetInfoFactory: priceAssetInfoFactory
            ),
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

    private func confirmAndCaptureOperation(_ setup: Setup) -> SubtensorStakingOperation? {
        let captor = ArgumentCaptor<SubtensorStakingOperation>()

        setup.presenter.confirm()

        verify(setup.interactor).submit(operation: captor.capture())

        return captor.value
    }

    func testRootConfirmSubmitsARootStake() {
        let setup = makeSetup { chainAsset in
            makeModel(for: chainAsset, target: .root, tolerance: nil, acknowledgedQuote: nil)
        }

        XCTAssertEqual(confirmAndCaptureOperation(setup), .rootStake(hotkey: hotkey, amount: stakeAmount))
    }

    func testSubnetConfirmSubmitsTheAcknowledgedLimitAfterAFillableRequote() throws {
        let acknowledged = try makeTradeQuote(spotPrice: 7_683_255)

        let setup = makeSetup { chainAsset in
            makeModel(
                for: chainAsset,
                target: makeSubnetTarget(price: 7_683_255),
                tolerance: SubtensorSlippageTolerance.defaultTolerance,
                acknowledgedQuote: acknowledged
            )
        }

        setup.presenter.didReceiveQuote(try makeTradeQuote(spotPrice: 7_690_000))

        XCTAssertEqual(
            confirmAndCaptureOperation(setup),
            .subnetBuy(hotkey: hotkey, netuid: 1, grossTao: stakeAmount, limitPrice: acknowledged.limitPrice)
        )
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
        verify(setup.interactor, never()).submit(operation: any())
    }
}
