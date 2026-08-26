import BigInt
import Cuckoo
import Foundation_iOS
@testable import novawallet
import XCTest

final class SubtensorUnstakeConfirmPresenterTests: XCTestCase {
    private let hotkey = Data(repeating: 0x22, count: 32)
    private let unstakeAmount = Balance(1_000_000_000)

    private struct Setup {
        let presenter: SubtensorUnstakeConfirmPresenter
        let wireframe: MockSubtensorUnstakeConfirmWireframeProtocol
        let interactor: MockSubtensorUnstakeConfirmInteractorInputProtocol
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
        taoOut: Balance = 7_660_000,
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

    private func makeModel(
        for chainAsset: ChainAsset,
        target: SubtensorStakeTarget,
        limitPrice: Balance?,
        slippage: BigRational?,
        quote: SubtensorQuote?
    ) -> SubtensorUnstakeConfirmModel {
        let address = (try? hotkey.toAddress(using: chainAsset.chain.chainFormat)) ?? ""

        return SubtensorUnstakeConfirmModel(
            delegate: DisplayAddress(address: address, username: ""),
            unstakeModel: SubtensorUnstakeModel(
                hotkey: hotkey,
                netuid: target.netuid,
                amount: unstakeAmount,
                isFullUnstake: false,
                limitPrice: limitPrice
            ),
            target: target,
            slippage: slippage,
            quote: quote
        )
    }

    private func makeSetup(model modelBuilder: (ChainAsset) -> SubtensorUnstakeConfirmModel) -> Setup {
        let chainAsset = makeChainAsset()

        let interactor = MockSubtensorUnstakeConfirmInteractorInputProtocol()

        stub(interactor) { stub in
            when(stub.setup()).thenDoNothing()
            when(stub.estimateFee(for: any())).thenDoNothing()
            when(stub.refreshPreflight(for: any(), netuid: any())).thenDoNothing()
            when(stub.refreshQuote(for: any())).thenDoNothing()
            when(stub.submit(call: any())).thenDoNothing()
        }

        let wireframe = MockSubtensorUnstakeConfirmWireframeProtocol()

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())

        let dataValidationFactory = SubtensorStakingValidationFactory(
            presentable: wireframe,
            assetDisplayInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let presenter = SubtensorUnstakeConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chainAsset: chainAsset,
            selectedAccount: makeSelectedAccount(for: chainAsset),
            model: modelBuilder(chainAsset),
            dataValidationFactory: dataValidationFactory,
            balanceViewModelFactory: BalanceViewModelFactory(
                targetAssetInfo: chainAsset.assetDisplayInfo,
                priceAssetInfoFactory: priceAssetInfoFactory
            ),
            quoteViewModelFactory: SubtensorQuoteViewModelFactory(chainAsset: chainAsset),
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

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

        return Setup(presenter: presenter, wireframe: wireframe, interactor: interactor)
    }

    private func confirmAndCaptureCall(_ setup: Setup) -> SubtensorStakingCallModel? {
        let captor = ArgumentCaptor<SubtensorStakingCallModel>()

        setup.presenter.confirm()

        verify(setup.interactor).submit(call: captor.capture())

        return captor.value
    }

    func testRootConfirmSubmitsPlainUnstakeWithoutLimitPrice() throws {
        let setup = makeSetup { chainAsset in
            makeModel(for: chainAsset, target: .root, limitPrice: nil, slippage: nil, quote: nil)
        }

        let call = try XCTUnwrap(confirmAndCaptureCall(setup))

        guard case let .unstake(model) = call else {
            return XCTFail("Expected unstake call")
        }

        XCTAssertEqual(model.netuid, SubtensorStakingPallet.rootNetuid)
        XCTAssertNil(model.limitPrice)
    }

    func testSubnetConfirmRederivesSellLimitFromNewestQuoteSpot() throws {
        let setup = makeSetup { chainAsset in
            makeModel(
                for: chainAsset,
                target: makeSubnetTarget(price: 7_000_000),
                limitPrice: 6_965_000,
                slippage: SubtensorSlippageTolerance.defaultTolerance,
                quote: makeQuote(spotPrice: 7_000_000)
            )
        }

        setup.presenter.didReceiveQuote(makeQuote(spotPrice: 7_683_255))

        let call = try XCTUnwrap(confirmAndCaptureCall(setup))

        guard case let .unstake(model) = call else {
            return XCTFail("Expected unstake call")
        }

        XCTAssertEqual(model.netuid, 1)
        XCTAssertEqual(model.limitPrice, 7_644_839)
    }

    func testSubnetConfirmKeepsTheSellLimitBelowTheSpotPrice() throws {
        let setup = makeSetup { chainAsset in
            makeModel(
                for: chainAsset,
                target: makeSubnetTarget(price: 7_683_255),
                limitPrice: 7_644_839,
                slippage: SubtensorSlippageTolerance.defaultTolerance,
                quote: makeQuote(spotPrice: 7_683_255)
            )
        }

        let call = try XCTUnwrap(confirmAndCaptureCall(setup))

        guard case let .unstake(model) = call else {
            return XCTFail("Expected unstake call")
        }

        let limitPrice = try XCTUnwrap(model.limitPrice)

        XCTAssertLessThan(limitPrice, 7_683_255)
    }
}
