import Cuckoo
import Foundation_iOS
@testable import novawallet
import XCTest

final class StartStakingInfoSubtensorPresenterTests: XCTestCase {
    func testStakingWalletKeepsHowEarningWorksOpen() {
        let wireframe = MockStartStakingInfoSubtensorWireframeProtocol()
        let presenter = makePresenter(wireframe: wireframe)

        stub(wireframe) { stub in
            when(stub.present(viewModel: any(), style: any(), from: any())).then { viewModel, _, _ in
                viewModel.actions.forEach { $0.handler?() }
            }
            when(stub.complete(from: any())).thenDoNothing()
        }

        presenter.didReceiveStakingEnabled()

        verify(wireframe, never()).complete(from: any())
    }

    func testBothSupportedEntryActionsUseTheirOwnRoutes() {
        let wireframe = MockStartStakingInfoSubtensorWireframeProtocol()
        let presenter = makePresenter(wireframe: wireframe)
        let view = MockStartStakingInfoViewProtocol()
        stub(view) { when($0.didReceive(balance: any())).thenDoNothing() }
        stub(wireframe) { stub in
            when(stub.showSetupAmount(from: any())).thenDoNothing()
            when(stub.showAllOptions(from: any())).thenDoNothing()
        }
        presenter.view = view
        let wallet = AccountGenerator.generateMetaAccount()
        presenter.didReceive(wallet: wallet, chainAccountId: wallet.substrateAccountId)
        presenter.didReceive(assetBalance: makeBalance())
        presenter.startStaking()
        presenter.seeAllOptions()
        verify(wireframe).showSetupAmount(from: any())
        verify(wireframe).showAllOptions(from: any())
    }

    func testBothEntryActionsKeepUnsupportedSignerAndMissingAccountGates() {
        for hasAccount in [true, false] {
            let wireframe = MockStartStakingInfoSubtensorWireframeProtocol()
            let presenter = makePresenter(wireframe: wireframe)
            let view = MockStartStakingInfoViewProtocol()
            stub(view) { when($0.didReceive(balance: any())).thenDoNothing() }
            stub(wireframe) { stub in
                when(stub.present(viewModel: any(), style: any(), from: any())).thenDoNothing()
                when(stub.presentSignerNotSupportedView(from: any(), type: any(), completion: any())).thenDoNothing()
                when(stub.present(message: any(), title: any(), closeAction: any(), from: any())).thenDoNothing()
            }
            presenter.view = view
            let wallet = AccountGenerator.generateMetaAccount(type: .ledger)
            presenter.didReceive(wallet: wallet, chainAccountId: hasAccount ? wallet.substrateAccountId : nil)
            if hasAccount { presenter.didReceive(assetBalance: makeBalance()) }
            presenter.startStaking()
            presenter.seeAllOptions()
            verify(wireframe, never()).showSetupAmount(from: any())
            verify(wireframe, never()).showAllOptions(from: any())
        }
    }

    private func makeBalance() -> AssetBalance {
        let asset = SubtensorFlowChainWorld.chainAsset()
        return AssetBalance(
            chainAssetId: asset.chainAssetId,
            accountId: Data(repeating: 1, count: 32),
            freeInPlank: 10_000_000_000,
            reservedInPlank: 0,
            frozenInPlank: 0,
            edCountMode: .basedOnFree,
            transferrableMode: .fungibleTrait,
            blocked: false
        )
    }

    private func makePresenter(
        wireframe: MockStartStakingInfoSubtensorWireframeProtocol
    ) -> StartStakingInfoSubtensorPresenter {
        let chainAsset = SubtensorFlowChainWorld.chainAsset()

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())
        )

        return StartStakingInfoSubtensorPresenter(
            chainAsset: chainAsset,
            interactor: MockStartStakingInfoSubtensorInteractorInputProtocol(),
            wireframe: wireframe,
            startStakingViewModelFactory: StartStakingViewModelFactory(
                balanceViewModelFactory: balanceViewModelFactory,
                estimatedEarningsFormatter: NumberFormatter.percentSingle.localizableResource()
            ),
            subtensorViewModelFactory: StartStakingInfoSubtensorViewModelFactory(),
            balanceDerivationFactory: StakingTypeBalanceFactory(stakingType: .subtensor),
            localizationManager: LocalizationManager.shared,
            applicationConfig: ApplicationConfig.shared,
            logger: Logger.shared
        )
    }
}
