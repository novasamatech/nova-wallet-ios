import XCTest
import Cuckoo
import SubstrateSdk
import SoraFoundation
import SoraKeystore
@testable import novawallet

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

        let eraCountdown = EraCountdown(
            activeEra: 102,
            currentEra: 102,
            eraLength: 10,
            sessionLength: 1,
            activeEraStartSessionIndex: 1,
            currentSessionIndex: 1,
            currentSlot: 2,
            genesisSlot: 1,
            blockCreationTime: 6000,
            createdAtDate: Date()
        )

        let input = StakingRewardDetailsInput(
            payoutInfo: payoutInfo,
            historyDepth: 84,
            eraCountdown: eraCountdown
        )

        let assetInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: assetInfo)
        let viewModelFactory = StakingRewardDetailsViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory,
            chainFormat: chain.chainFormat
        )

        let timeleftFactory = PayoutTimeViewModelFactory(
            timeFormatter: TotalTimeFormatter()
        )

        let presenter = StakingRewardDetailsPresenter(
            input: input,
            viewModelFactory: viewModelFactory,
            timeleftFactory: timeleftFactory,
            explorers: nil,
            chainFormat: chain.chainFormat,
            localizationManager: LocalizationManager.shared
        )
        presenter.wireframe = wireframe
        presenter.view = view
        presenter.interactor = interactor
        interactor.presenter = presenter

        let amountExpectation = XCTestExpectation()
        let validatorExpectation = XCTestExpectation()
        let eraExpectation = XCTestExpectation()
        let remainedTimeExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didReceive(amountViewModel: any()).then { _ in
                amountExpectation.fulfill()
            }

            when(stub).didReceive(validatorViewModel: any()).then { _ in
                validatorExpectation.fulfill()
            }

            when(stub).didReceive(eraViewModel: any()).then { _ in
                eraExpectation.fulfill()
            }

            when(stub).didReceive(remainedTime: any()).then { _ in
                remainedTimeExpectation.fulfill()
            }
        }

        // when

        presenter.setup()

        // then

        wait(
            for: [amountExpectation, validatorExpectation, eraExpectation],
            timeout: Constants.defaultExpectationDuration
        )

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
