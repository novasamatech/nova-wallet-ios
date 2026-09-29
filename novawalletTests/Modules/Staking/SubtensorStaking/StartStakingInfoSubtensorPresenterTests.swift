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
