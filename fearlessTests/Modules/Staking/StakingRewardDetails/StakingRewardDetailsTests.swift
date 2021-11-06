import XCTest
import Cuckoo
import SubstrateSdk
import SoraFoundation
import SoraKeystore
@testable import fearless

class StakingRewardDetailsTests: XCTestCase {

    func testSetupAndHandlePayout() {
        let chain = ChainModelGenerator.generateChain(
            generatingAssets: 2,
            addressPrefix: 42,
            assetPresicion: 12,
            hasStaking: true
        )

        let chainAsset = ChainAsset(chain: chain, asset: chain.assets.first!)

        let view = MockStakingRewardDetailsViewProtocol()
        let wireframe = MockStakingRewardDetailsWireframeProtocol()

        let priceProviderFactory = PriceProviderFactoryStub(
            priceData: PriceData(price: "0.1", usdDayChange: 0.1)
        )

        let interactor = StakingRewardDetailsInteractor(
            asset: chainAsset.asset,
            priceLocalSubscriptionFactory: priceProviderFactory
        )

        let payoutInfo = PayoutInfo(
            era: 100,
            validator: Data(),
            reward: 1,
            identity: nil
        )
        let input = StakingRewardDetailsInput(
            payoutInfo: payoutInfo,
            activeEra: 101,
            historyDepth: 84,
            erasPerDay: 4
        )

        let assetInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: assetInfo)
        let viewModelFactory = StakingRewardDetailsViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory,
            iconGenerator: PolkadotIconGenerator(),
            chainFormat: chain.chainFormat
        )
        let presenter = StakingRewardDetailsPresenter(
            input: input,
            viewModelFactory: viewModelFactory,
            explorers: nil
        )
        presenter.wireframe = wireframe
        presenter.view = view
        presenter.interactor = interactor
        interactor.presenter = presenter

        let rowsExpectation = XCTestExpectation(description: "rows count is equal to 4")
        stub(view) { stub in
            when(stub).reload(with: any()).then { resource in
                let rows = resource.value(for: .current).rows
                if rows.count == 4 {
                    rowsExpectation.fulfill()
                }
            }
        }

        // when
        presenter.setup()
        // then
        wait(for: [rowsExpectation], timeout: Constants.defaultExpectationDuration)

        let handlePayoutActionExpectation = XCTestExpectation(description: "wireframe method is called")
        stub(wireframe) { stub in
            when(stub).showPayoutConfirmation(from: any(), payoutInfo: any()).then { _ in
                handlePayoutActionExpectation.fulfill()
            }
        }

        // when
        presenter.handlePayoutAction()
        // then
        wait(for: [handlePayoutActionExpectation], timeout: Constants.defaultExpectationDuration)
    }
}
