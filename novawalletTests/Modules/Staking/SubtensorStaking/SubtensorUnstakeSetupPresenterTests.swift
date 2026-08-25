import XCTest
import Cuckoo
import BigInt
import Foundation_iOS
@testable import novawallet

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
            subtokenEnabled: true,
            hasColdkeySwapAnnouncement: false,
            isSafeModeActive: false,
            stakeAvailability: nil,
            rootStakeUnlockInterval: 0,
            lastStakeBlock: nil,
            minStake: 2_000_000,
            effectiveNominatorMinStake: 1,
            rootClaimableThreshold: 500_000,
            delegateTake: 11_796
        )
    }

    private func makeSetup() -> Setup {
        let chainAsset = makeChainAsset()

        let interactor = MockSubtensorUnstakeSetupInteractorInputProtocol()

        stub(interactor) { stub in
            when(stub.setup()).thenDoNothing()
            when(stub.estimateFee(for: any())).thenDoNothing()
            when(stub.refreshPreflight(for: any())).thenDoNothing()
            when(stub.applyDelegate(with: any())).thenDoNothing()
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
            dataValidationFactory: dataValidationFactory,
            balanceViewModelFactory: BalanceViewModelFactory(
                targetAssetInfo: chainAsset.assetDisplayInfo,
                priceAssetInfoFactory: priceAssetInfoFactory
            ),
            accountDetailsViewModelFactory: CollatorStakingAccountViewModelFactory(chainAsset: chainAsset),
            initialPosition: SubtensorStakingPosition(
                hotkey: hotkey,
                netuid: SubtensorStakingPallet.rootNetuid,
                stakeAlpha: stakedAmount,
                hotkeyEmissionPerTempo: 0,
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
                        netuid: SubtensorStakingPallet.rootNetuid,
                        stakeAlpha: stakedAmount,
                        hotkeyEmissionPerTempo: 0,
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
            ExtrinsicFee(amount: 1_000_000, payer: nil, weight: .init(refTime: 1_000, proofSize: 0))
        )

        presenter.didReceivePreflight(makePreflight())

        return Setup(presenter: presenter, wireframe: wireframe, interactor: interactor)
    }

    private func proceedAndCaptureModel(_ setup: Setup) -> SubtensorUnstakeConfirmModel? {
        let captor = ArgumentCaptor<SubtensorUnstakeConfirmModel>()

        stub(setup.wireframe) { stub in
            when(stub.showConfirm(from: any(), model: any())).thenDoNothing()
        }

        setup.presenter.didReceiveFee(
            ExtrinsicFee(amount: 1_000_000, payer: nil, weight: .init(refTime: 1_000, proofSize: 0))
        )

        setup.presenter.proceed()

        verify(setup.wireframe).showConfirm(from: any(), model: captor.capture())

        return captor.value
    }

    func testHundredPercentRateProducesFullUnstake() {
        let setup = makeSetup()

        setup.presenter.selectAmountPercentage(1.0)

        let model = proceedAndCaptureModel(setup)

        XCTAssertEqual(model?.unstakeModel.isFullUnstake, true)
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
}
