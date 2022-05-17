import XCTest
@testable import novawallet
import SoraKeystore
import Cuckoo
import RobinHood
import IrohaCrypto
import SoraFoundation
import BigInt

class StakingMainTests: XCTestCase {
    func testNominatorStateSetup() throws {
        // given

        let substrateStorageFacade = SubstrateStorageTestFacade()
        let userStorageFacade = UserDataStorageTestFacade()
        let selectedMetaAccount = AccountGenerator.generateMetaAccount()
        let selectedChain = ChainModelGenerator.generateChain(
            generatingAssets: 2,
            addressPrefix: 42,
            assetPresicion: 12,
            hasStaking: true
        )

        let walletSettings = SelectedWalletSettings(
            storageFacade: userStorageFacade,
            operationQueue: OperationQueue()
        )

        walletSettings.save(value: selectedMetaAccount)

        let chainRegistry = MockChainRegistryProtocol().applyDefault(for: [selectedChain])

        let stakingSettings = StakingAssetSettings(
            chainRegistry: chainRegistry,
            settings: InMemorySettingsManager()
        )

        let selectedChainAsset = ChainAsset(chain: selectedChain, asset: selectedChain.assets.first!)
        stakingSettings.save(value: selectedChainAsset)

        let operationManager = OperationManager()

        let eventCenter = MockEventCenterProtocol().applyingDefaultStub()

        let view = MockStakingMainViewProtocol()
        let wireframe = MockStakingRelaychainWireframeProtocol()

        let calculatorService = RewardCalculatorServiceStub(engine: WestendStub.rewardCalculator)
        let eraValidatorService = EraValidatorServiceStub.westendStub()

        let viewModelFacade = StakingViewModelFacade()
        let analyticsRewardsViewModelFactoryBuilder: AnalyticsRewardsViewModelFactoryBuilder = { chainAsset, balance in
            AnalyticsRewardsViewModelFactory(
                assetInfo: chainAsset.assetDisplayInfo,
                balanceViewModelFactory: balance,
                calendar: .init(identifier: .gregorian)
            )
        }
        let stateViewModelFactory = StakingStateViewModelFactory(
            analyticsRewardsViewModelFactoryBuilder: analyticsRewardsViewModelFactoryBuilder,
            logger: Logger.shared
        )

        let networkViewModelFactory = NetworkInfoViewModelFactory()

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)
        let presenter = StakingRelaychainPresenter(
            stateViewModelFactory: stateViewModelFactory,
            networkInfoViewModelFactory: networkViewModelFactory,
            viewModelFacade: viewModelFacade,
            dataValidatingFactory: dataValidatingFactory,
            logger: Logger.shared
        )

        let eraInfoOperationFactory = MockNetworkStakingInfoOperationFactoryProtocol()

        let accountProviderFactory = AccountProviderFactory(
            storageFacade: UserDataStorageTestFacade(),
            operationManager: operationManager
        )

        let eraCountdownOperationFactory = EraCountdownOperationFactoryStub(eraCountdown: .testStub)

        let accountResponse = selectedMetaAccount.fetch(for: selectedChain.accountRequest())!
        let address = try accountResponse.accountId.toAddress(using: selectedChain.chainFormat)

        let stakingLocalSubscriptionFactory = StakingLocalSubscriptionFactoryStub(
            minNominatorBond: 0,
            counterForNominators: 10,
            maxNominatorsCount: 100,
            nomination: Nomination(targets: [Data(repeating: 0, count: 32)], submittedIn: 10),
            validatorPrefs: nil,
            ledgerInfo: StakingLedger(
                stash: accountResponse.accountId,
                total: BigUInt(1e+12),
                active: BigUInt(1e+12),
                unlocking: [],
                claimedRewards: []
            ),
            activeEra: ActiveEraInfo(index: 15),
            currentEra: 15,
            payee: RewardDestinationArg.staked,
            totalReward: nil,
            stashItem: StashItem(stash: address, controller: address),
            storageFacade: substrateStorageFacade
        )

        let rewardAnalyticsProviderFactory = StakingAnalyticsLocalSubscriptionFactoryStub(
            weaklyAnalytics: []
        )

        let sharedState = StakingSharedState(
            settings: stakingSettings,
            eraValidatorService: eraValidatorService,
            rewardCalculationService: calculatorService,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            stakingAnalyticsLocalSubscriptionFactory: rewardAnalyticsProviderFactory
        )

        let stakingServiceFactory = MockStakingServiceFactoryProtocol().apply(
            eraValidatorService: eraValidatorService,
            rewardCalculatorService: calculatorService
        )

        let walletLocalSubscriptionService = WalletLocalSubscriptionFactoryStub(
            balance: BigUInt(1e+18)
        )

        let interactor = StakingRelaychainInteractor(
            selectedWalletSettings: walletSettings,
            sharedState: sharedState,
            chainRegistry: chainRegistry,
            stakingRemoteSubscriptionService: MockStakingRemoteSubscriptionServiceProtocol().applyDefault(),
            stakingAccountUpdatingService: MockStakingAccountUpdatingServiceProtocol().applyDefault(),
            walletLocalSubscriptionFactory: walletLocalSubscriptionService,
            priceLocalSubscriptionFactory: PriceProviderFactoryStub(),
            stakingServiceFactory: stakingServiceFactory,
            accountProviderFactory: accountProviderFactory,
            eventCenter: eventCenter,
            operationManager: operationManager,
            eraInfoOperationFactory: eraInfoOperationFactory,
            applicationHandler: ApplicationHandler(),
            eraCountdownOperationFactory: eraCountdownOperationFactory
        )

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        interactor.presenter = presenter
        dataValidatingFactory.view = view

        // when

        let nominatorStateExpectation = XCTestExpectation()
        let networkStakingInfoExpectation = XCTestExpectation()
        let staticsExpectation = XCTestExpectation()

        stub(eraInfoOperationFactory) { stub in
            when(stub).networkStakingOperation(for: any(), runtimeService: any()).then { _ in
                CompoundOperationWrapper.createWithResult(
                    NetworkStakingInfo(
                        totalStake: BigUInt.zero,
                        minStakeAmongActiveNominators: BigUInt.zero,
                        minimalBalance: BigUInt.zero,
                        activeNominatorsCount: 0,
                        lockUpPeriod: 0,
                        stakingDuration: StakingDuration(
                            session: 60,
                            era: 120,
                            unlocking: 180
                        )
                    )
                )
            }
        }

        stub(view) { stub in
            stub.didRecieveNetworkStakingInfo(viewModel: any()).then { _ in
                networkStakingInfoExpectation.fulfill()
            }

            stub.didReceiveStakingState(viewModel: any()).then { state in
                if case .nominator = state {
                    nominatorStateExpectation.fulfill()
                }
            }

            stub.didReceiveStatics(viewModel: any()).then { state in
                staticsExpectation.fulfill()
            }
        }

        presenter.setup()

        // then

        let expectations = [
            nominatorStateExpectation,
            networkStakingInfoExpectation,
            staticsExpectation
        ]

        wait(for: expectations, timeout: 5)
    }

    private func performStakingManageTestSetup(
        for wireframe: StakingRelaychainWireframeProtocol
    ) -> StakingRelaychainPresenter {
        let interactor = StakingRelaychainInteractorInputProtocolStub()

        let viewModelFacade = StakingViewModelFacade()
        let analyticsRewardsViewModelFactoryBuilder: AnalyticsRewardsViewModelFactoryBuilder = { chainAsset, balance in
            AnalyticsRewardsViewModelFactory(
                assetInfo: chainAsset.assetDisplayInfo,
                balanceViewModelFactory: balance,
                calendar: .init(identifier: .gregorian)
            )
        }
        let stateViewModelFactory = StakingStateViewModelFactory(
            analyticsRewardsViewModelFactoryBuilder: analyticsRewardsViewModelFactoryBuilder,
            logger: nil
        )

        let networkViewModelFactory = NetworkInfoViewModelFactory()

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        let presenter = StakingRelaychainPresenter(
            stateViewModelFactory: stateViewModelFactory,
            networkInfoViewModelFactory: networkViewModelFactory,
            viewModelFacade: viewModelFacade,
            dataValidatingFactory: dataValidatingFactory,
            logger: nil
        )

        presenter.wireframe = wireframe
        presenter.interactor = interactor

        let selectedChain = ChainModelGenerator.generateChain(
            generatingAssets: 2,
            addressPrefix: 42,
            assetPresicion: 12,
            hasStaking: true
        )

        let selectedChainAsset = ChainAsset(chain: selectedChain, asset: selectedChain.assets.first!)

        presenter.didReceive(newChainAsset: selectedChainAsset)
        presenter.didReceive(stashItem: StashItem(stash: WestendStub.address, controller: WestendStub.address))
        presenter.didReceive(ledgerInfo: WestendStub.ledgerInfo.item)
        presenter.didReceive(nomination: WestendStub.nomination.item)

        return presenter
    }
}
