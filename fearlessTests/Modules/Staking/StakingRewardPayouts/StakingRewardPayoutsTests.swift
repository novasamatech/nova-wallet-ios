import XCTest
import Cuckoo
import RobinHood
import SoraFoundation
@testable import fearless

class StakingRewardPayoutsTests: XCTestCase {

    func testViewStateIsLoadingThenError() {
        let chain = ChainModelGenerator.generateChain(
            generatingAssets: 2,
            addressPrefix: 42,
            assetPresicion: 12,
            hasStaking: true
        )

        let chainAsset = ChainAsset(chain: chain, asset: chain.assets.first!)

        let payoutServiceThatReturnsError = PayoutRewardsServiceStub.error()
        let eraCountdownOperationFactory = EraCountdownOperationFactoryStub(eraCountdown: .testStub)

        let chainRegistry = MockChainRegistryProtocol().applyDefault(for: [chain])

        let stakingLocalSubscriptionFactory = StakingLocalSubscriptionFactoryStub()
        let priceLocalSubscriptionFactory = PriceProviderFactoryStub()

        let interactor = StakingRewardPayoutsInteractor(
            chainAsset: chainAsset,
            chainRegistry: chainRegistry,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            payoutService: payoutServiceThatReturnsError,
            eraCountdownOperationFactory: eraCountdownOperationFactory,
            operationManager: OperationManager()
        )

        let view = MockStakingRewardPayoutsViewProtocol()

        let viewModelFactory = MockStakingPayoutViewModelFactoryProtocol()
        let presenter = StakingRewardPayoutsPresenter(
            viewModelFactory: viewModelFactory
        )
        presenter.interactor = interactor
        presenter.view = view
        interactor.presenter = presenter

        // given
        let viewStateIsLoadingOnPresenterSetup = XCTestExpectation()
        let viewStateIsNotLoadingWhenPresenterRecievedResult = XCTestExpectation()
        let viewStateIsErrorWhenPresenterRecievedError = XCTestExpectation()

        stub(view) { stub in
            when(stub).reload(with: any())
                .then { viewState in
                    if case let StakingRewardPayoutsViewState.loading(loading) = viewState, loading {
                        viewStateIsLoadingOnPresenterSetup.fulfill()
                    }
                }
                .then { viewState in
                    if case let StakingRewardPayoutsViewState.loading(loading) = viewState, !loading {
                        viewStateIsNotLoadingWhenPresenterRecievedResult.fulfill()
                    }
                }.then { viewState in
                    if case StakingRewardPayoutsViewState.error(_) = viewState {
                        viewStateIsErrorWhenPresenterRecievedError.fulfill()
                    }
                }
        }

        // when
        presenter.setup()

        // then
        wait(
            for: [
                viewStateIsLoadingOnPresenterSetup,
                viewStateIsNotLoadingWhenPresenterRecievedResult,
                viewStateIsErrorWhenPresenterRecievedError
            ],
            timeout: Constants.defaultExpectationDuration
        )
        verify(view, times(3)).reload(with: any())
        XCTAssert(payoutServiceThatReturnsError.fetchPayoutsCounter == 1)
    }

    func testHandlePresenterActions() {
        // given
        let interactor = MockStakingRewardPayoutsInteractorInputProtocol()
        let wireframe = MockStakingRewardPayoutsWireframeProtocol()
        let view = MockStakingRewardPayoutsViewProtocol()

        let viewModelFactory = MockStakingPayoutViewModelFactoryProtocol()
        let presenter = StakingRewardPayoutsPresenter(
            viewModelFactory: viewModelFactory
        )
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        presenter.view = view

        stub(interactor) { stub in
            when(stub).setup().then {
                if case let Result.success(payoutsInfo) = PayoutRewardsServiceStub.dummy().result {
                    presenter.didReceive(result: .success(payoutsInfo))
                }

                let eraCountdown = EraCountdown(
                    activeEra: 1,
                    currentEra: 1,
                    eraLength: 10,
                    sessionLength: 1,
                    activeEraStartSessionIndex: 1,
                    currentSessionIndex: 1,
                    currentSlot: 2,
                    genesisSlot: 1,
                    blockCreationTime: 6000,
                    createdAtDate: Date()
                )

                presenter.didReceive(eraCountdownResult: .success(eraCountdown))
            }
        }

        stub(viewModelFactory) { stub in
            when(stub).createPayoutsViewModel(payoutsInfo: any(), priceData: any(), eraCountdown: any()).then { _ in
                LocalizableResource { _ in
                    StakingPayoutViewModel(
                        cellViewModels: [],
                        eraComletionTime: nil,
                        bottomButtonTitle: ""
                    )
                }
            }
        }

        let viewStateIsPayoutListExpectation = XCTestExpectation()
        stub(view) { stub in
            when(stub).reload(with: any()).then { viewState in
                if case StakingRewardPayoutsViewState.payoutsList(_) = viewState {
                    viewStateIsPayoutListExpectation.fulfill()
                }
            }
        }

        let showRewardDetailsExpectation = XCTestExpectation()
        stub(wireframe) { stub in
            when(stub)
                .showRewardDetails(from: any(), payoutInfo: any(), activeEra: any(), historyDepth: any(), erasPerDay: any())
                .then { _ in
                    showRewardDetailsExpectation.fulfill()
                }
        }

        let showPayoutConfirmationExpectation = XCTestExpectation()
        stub(wireframe) { stub in
            when(stub)
                .showPayoutConfirmation(for: any(), from: any())
                .then { _ in
                    showPayoutConfirmationExpectation.fulfill()
                }
        }

        // when
        presenter.setup()
        presenter.handleSelectedHistory(at: 0)
        presenter.handlePayoutAction()

        // then
        wait(
            for: [
                viewStateIsPayoutListExpectation,
                showRewardDetailsExpectation,
                showPayoutConfirmationExpectation
            ],
            timeout: Constants.defaultExpectationDuration
        )
    }
}
