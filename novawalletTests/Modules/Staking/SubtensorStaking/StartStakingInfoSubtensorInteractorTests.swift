import Cuckoo
import Foundation_iOS
import Keystore_iOS
@testable import novawallet
import Operation_iOS
import XCTest

final class StartStakingInfoSubtensorInteractorTests: XCTestCase {
    private struct Setup {
        let interactor: StartStakingInfoSubtensorInteractor
        let presenter: StartStakingInfoSubtensorPresenter
        let wireframe: MockStartStakingInfoSubtensorWireframeProtocol
        let walletSettings: SelectedWalletSettings
        let eventCenter: MockEventCenterProtocol
    }

    func testSwitchingToAnotherWalletClosesHowEarningWorks() throws {
        let setup = makeSetup(selecting: AccountGenerator.generateMetaAccount())

        setup.interactor.setup()
        setup.walletSettings.internalValue = AccountGenerator.generateMetaAccount()
        SelectedWalletSwitched().accept(visitor: try registeredObserver(in: setup.eventCenter))

        verify(setup.wireframe).close(from: any())
    }

    func testRemovingAnotherWalletKeepsHowEarningWorksOpen() throws {
        let setup = makeSetup(selecting: AccountGenerator.generateMetaAccount())

        setup.interactor.setup()
        WalletRemoved().accept(visitor: try registeredObserver(in: setup.eventCenter))

        verify(setup.wireframe, never()).close(from: any())
    }

    func testRemovingTheBoundWalletClosesHowEarningWorksOnce() throws {
        let setup = makeSetup(selecting: AccountGenerator.generateMetaAccount())

        setup.interactor.setup()
        setup.walletSettings.internalValue = AccountGenerator.generateMetaAccount()

        let observer = try registeredObserver(in: setup.eventCenter)
        WalletRemoved().accept(visitor: observer)
        SelectedWalletSwitched().accept(visitor: observer)

        verify(setup.wireframe, times(1)).close(from: any())
    }

    func testReplacingTheBoundWalletTaoAccountClosesHowEarningWorks() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let setup = makeSetup(selecting: wallet)

        setup.interactor.setup()
        setup.walletSettings.internalValue = wallet.replacingChainAccount(
            AccountGenerator.generateChainAccount(with: SubtensorFlowChainWorld.chainAsset().chain.chainId)
        )
        ChainAccountChanged().accept(visitor: try registeredObserver(in: setup.eventCenter))

        verify(setup.wireframe).close(from: any())
    }

    private func makeSetup(selecting wallet: MetaAccountModel) -> Setup {
        let chainAsset = SubtensorFlowChainWorld.chainAsset()
        let wireframe = MockStartStakingInfoSubtensorWireframeProtocol()
        let eventCenter = MockEventCenterProtocol()

        stub(wireframe) { stub in
            when(stub.close(from: any())).thenDoNothing()
        }

        stub(eventCenter) { stub in
            when(stub.add(observer: any(), dispatchIn: any())).thenDoNothing()
        }

        let walletSettings = SelectedWalletSettings(
            storageFacade: UserDataStorageTestFacade(),
            operationQueue: OperationQueue()
        )

        walletSettings.internalValue = wallet

        let interactor = StartStakingInfoSubtensorInteractor(
            state: makeState(chainAsset: chainAsset),
            maxApyProvider: makeMaxApyProvider(),
            selectedWalletSettings: walletSettings,
            eventCenter: eventCenter,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryStub(),
            priceLocalSubscriptionFactory: PriceProviderFactoryStub(),
            stakingDashboardProviderFactory: makeDashboardProviderFactory(),
            announcementsRepository: makeAnnouncementsRepository(),
            currencyManager: CurrencyManagerStub(),
            sharedOperation: SharedOperation(),
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )

        let presenter = makePresenter(chainAsset: chainAsset, interactor: interactor, wireframe: wireframe)

        interactor.presenter = presenter

        return Setup(
            interactor: interactor,
            presenter: presenter,
            wireframe: wireframe,
            walletSettings: walletSettings,
            eventCenter: eventCenter
        )
    }

    private func makePresenter(
        chainAsset: ChainAsset,
        interactor: StartStakingInfoSubtensorInteractor,
        wireframe: MockStartStakingInfoSubtensorWireframeProtocol
    ) -> StartStakingInfoSubtensorPresenter {
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())
        )

        return StartStakingInfoSubtensorPresenter(
            chainAsset: chainAsset,
            interactor: interactor,
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

    private func makeState(chainAsset: ChainAsset) -> MockSubtensorStakingSharedStateProtocol {
        let state = MockSubtensorStakingSharedStateProtocol()

        stub(state) { stub in
            when(stub.stakingOption.get).thenReturn(Multistaking.ChainAssetOption(chainAsset: chainAsset, type: .subtensor))
            when(stub.setup(for: any())).thenDoNothing()
            when(stub.throttle()).thenDoNothing()
        }

        return state
    }

    private func makeMaxApyProvider() -> MockSubtensorMaxApyProviderProtocol {
        let maxApyProvider = MockSubtensorMaxApyProviderProtocol()

        stub(maxApyProvider) { stub in
            when(stub.createMaxApyWrapper()).thenReturn(CompoundOperationWrapper.createWithError(CommonError.dataCorruption))
        }

        return maxApyProvider
    }

    private func makeDashboardProviderFactory() -> MockStakingDashboardProviderFactoryProtocol {
        let factory = MockStakingDashboardProviderFactoryProtocol()

        stub(factory) { stub in
            when(stub.getDashboardItemsProvider(for: any(), chainAssetId: any())).thenReturn(nil)
        }

        return factory
    }

    private func makeAnnouncementsRepository() -> MockAnnouncementsRepositoryProtocol {
        let repository = MockAnnouncementsRepositoryProtocol()

        stub(repository) { stub in
            when(stub.fetchAnnouncementsWrapper(for: any())).thenReturn(CompoundOperationWrapper.createWithResult([]))
        }

        return repository
    }

    private func registeredObserver(in eventCenter: MockEventCenterProtocol) throws -> EventVisitorProtocol {
        let captor = ArgumentCaptor<EventVisitorProtocol>()

        verify(eventCenter).add(observer: captor.capture(), dispatchIn: any())

        return try XCTUnwrap(captor.value)
    }
}
