import Cuckoo
import Foundation_iOS
import Keystore_iOS
@testable import novawallet
import Operation_iOS
import XCTest

final class SubtensorPortfolioInteractorTests: XCTestCase {
    private struct Setup {
        let interactor: SubtensorPortfolioInteractor
        let presenter: SubtensorPortfolioPresenter
        let wireframe: MockSubtensorPortfolioWireframeProtocol
        let state: MockSubtensorStakingSharedStateProtocol
        let walletSettings: SelectedWalletSettings
    }

    func testLeavingAndReenteringAPositionKeepsTheStateBound() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let setup = try makeSetup(selecting: wallet)

        setup.interactor.setup()
        openAndLeavePosition(on: setup.state)
        openAndLeavePosition(on: setup.state)

        verify(setup.state).setup(for: ParameterMatcher<MetaChainAccountResponse?> { $0?.metaId == wallet.metaId })
        verify(setup.state, never()).throttle()
    }

    func testReleasingYourBittensorThrottlesItsStateOnce() throws {
        var setup: Setup? = try makeSetup(selecting: AccountGenerator.generateMetaAccount())
        let state = try XCTUnwrap(setup?.state)
        let throttled = expectation(description: "State throttled")

        stub(state) { stub in
            when(stub.throttle()).then { throttled.fulfill() }
        }

        setup?.interactor.setup()
        setup = nil

        wait(for: [throttled], timeout: 10)
        verify(state).throttle()
    }

    func testSwitchingToAnotherWalletClosesYourBittensor() throws {
        let eventCenter = makeEventCenter()
        let setup = try makeSetup(selecting: AccountGenerator.generateMetaAccount(), eventCenter: eventCenter)

        stub(setup.wireframe) { stub in
            when(stub.close(from: any())).thenDoNothing()
        }

        setup.interactor.setup()
        setup.walletSettings.internalValue = AccountGenerator.generateMetaAccount()
        SelectedWalletSwitched().accept(visitor: try registeredObserver(in: eventCenter))

        verify(setup.wireframe).close(from: any())
    }

    func testRemovingAnotherWalletKeepsYourBittensorOpen() throws {
        let eventCenter = makeEventCenter()
        let setup = try makeSetup(selecting: AccountGenerator.generateMetaAccount(), eventCenter: eventCenter)

        setup.interactor.setup()
        WalletRemoved().accept(visitor: try registeredObserver(in: eventCenter))

        verify(setup.wireframe, never()).close(from: any())
    }

    func testAddPositionOnAWatchOnlyWalletOpensHowEarningWorks() throws {
        let setup = try makeSetup(selecting: AccountGenerator.createWatchOnly(for: Data(repeating: 7, count: 32)))

        stub(setup.wireframe) { stub in
            when(stub.showAddPosition(from: any())).thenDoNothing()
        }

        setup.presenter.addPosition()

        verify(setup.wireframe).showAddPosition(from: any())
    }

    func testAddPositionOnALedgerWalletKeepsHowEarningWorksClosed() throws {
        let setup = try makeSetup(selecting: AccountGenerator.generateMetaAccount(type: .ledger))

        stub(setup.wireframe) { stub in
            when(stub.showAddPosition(from: any())).thenDoNothing()
        }

        setup.presenter.addPosition()

        verify(setup.wireframe, never()).showAddPosition(from: any())
    }

    func testCurrencyChangeRerendersTheFiatInTheNewCurrency() throws {
        let interactor = makeInteractor()
        let view = MockSubtensorPortfolioViewProtocol()
        let currencyManager = CurrencyManagerStub()
        let euro = Currency(
            id: 2,
            code: "EUR",
            name: "Euro",
            symbol: "€",
            category: .fiat,
            isPopular: true,
            coingeckoId: "eur"
        )

        currencyManager.availableCurrencies = [.usd, euro]

        let viewModels = capture(view)
        let presenter = makePresenter(interactor: interactor, view: view, currencyManager: currencyManager)

        presenter.didReceive(state: makeRootState(stake: 20_000_000_000))
        presenter.didReceive(catalogue: nil)
        presenter.didReceive(price: PriceData(identifier: "bittensor", price: "342", dayChange: nil, currencyId: Currency.usd.id))

        XCTAssertEqual(viewModels.lastHeader?.fiat, .loaded("$6,840"))

        presenter.didChangeCurrency()

        XCTAssertEqual(viewModels.lastHeader?.fiat, .loading)
        XCTAssertEqual(viewModels.lastHeader?.chart, .loading)

        presenter.didReceive(price: PriceData(identifier: "bittensor", price: "300", dayChange: nil, currencyId: euro.id))

        XCTAssertEqual(viewModels.lastHeader?.fiat, .loaded("€6,000"))
        verify(interactor, times(2)).loadHistories(for: equal(to: .month))
    }

    func testCurrencyChangeResubscribesThePriceInTheNewCurrency() throws {
        let currencyManager = CurrencyManager(
            settingsManager: InMemorySettingsManager(),
            availableCurrencies: [.usd, .btc],
            selectedCurrency: .usd
        )

        let priceFactory = MockPriceProviderFactoryProtocol()
        let presenter = MockSubnetPortfolioInteractorOutputProtocol()

        stub(priceFactory) { stub in
            when(stub.getPriceStreamableProvider(for: any(), currency: any())).thenReturn(
                PriceProviderFactoryStub().getPriceStreamableProvider(for: "bittensor", currency: .btc)
            )
        }

        stub(presenter) { stub in
            when(stub.didChangeCurrency()).thenDoNothing()
            when(stub.didReceive(price: any())).thenDoNothing()
        }

        let setup = try makeSetup(
            selecting: AccountGenerator.generateMetaAccount(),
            priceLocalSubscriptionFactory: priceFactory,
            currencyManager: currencyManager
        )

        setup.interactor.presenter = presenter
        currencyManager.selectedCurrency = .btc

        verify(presenter).didChangeCurrency()
        verify(priceFactory).getPriceStreamableProvider(for: equal(to: "bittensor"), currency: equal(to: Currency.btc))
    }

    func testPositionsDroppingToZeroSwitchYourBittensorToTheEmptyLayout() {
        let view = MockSubtensorPortfolioViewProtocol()
        let viewModels = capture(view)
        let presenter = makePresenter(interactor: makeInteractor(), view: view, currencyManager: CurrencyManagerStub())

        presenter.didReceive(state: makeRootState(stake: 20_000_000_000))

        XCTAssertNotNil(viewModels.lastHeader)
        XCTAssertNil(viewModels.lastEmpty)

        presenter.didReceive(state: Multistaking.SubtensorStakingState(positions: [], prices: [:]))

        XCTAssertEqual(
            viewModels.lastEmpty,
            SubtensorPortfolioEmptyViewModel(total: "0 TAO", fiat: nil, rootSubtitle: "Paid in TAO · no swap")
        )
    }

    private func makeSetup(
        selecting wallet: MetaAccountModel,
        eventCenter: EventCenterProtocol = EventCenter(),
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol = PriceProviderFactoryStub(),
        currencyManager: CurrencyManagerProtocol = CurrencyManagerStub()
    ) throws -> Setup {
        let chainAsset = SubtensorFlowChainWorld.chainAsset()
        let account = try XCTUnwrap(wallet.fetchMetaChainAccount(for: chainAsset.chain.accountRequest()))
        let state = makeState(chainAsset: chainAsset, account: account)
        let wireframe = MockSubtensorPortfolioWireframeProtocol()

        let walletSettings = SelectedWalletSettings(
            storageFacade: UserDataStorageTestFacade(),
            operationQueue: OperationQueue()
        )

        walletSettings.internalValue = wallet

        let interactor = SubtensorPortfolioInteractor(
            state: state,
            account: account,
            selectedWalletSettings: walletSettings,
            eventCenter: eventCenter,
            applicationHandler: ApplicationHandler(),
            catalogueService: MockSubtensorSubnetCatalogueServiceProtocol(),
            yieldService: makeYieldService(),
            subnetLogosProvider: makeSubnetLogosProvider(),
            priceHistoryService: nil,
            portfolioHistoryService: MockSubtensorPortfolioHistoryServiceProtocol(),
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            currencyManager: currencyManager,
            flowState: SubtensorStakingFlowState(
                coingeckoOperationFactory: CoingeckoOperationFactory(),
                operationQueue: OperationQueue()
            ),
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )

        let presenter = SubtensorPortfolioPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: SubtensorPortfolioViewModelFactory(
                chainAsset: chainAsset,
                priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())
            ),
            account: account,
            chainAsset: chainAsset,
            localizationManager: LocalizationManager.shared
        )

        interactor.presenter = presenter

        return Setup(
            interactor: interactor,
            presenter: presenter,
            wireframe: wireframe,
            state: state,
            walletSettings: walletSettings
        )
    }

    private func makeState(
        chainAsset: ChainAsset,
        account: MetaChainAccountResponse
    ) -> MockSubtensorStakingSharedStateProtocol {
        let state = MockSubtensorStakingSharedStateProtocol()
        let subnetsService = MockSubtensorSubnetsServiceProtocol()

        stub(subnetsService) { stub in
            when(stub.fetchSubnetsInfo(forcingRefresh: any(), runningCompletionIn: any(), completion: any()))
                .thenDoNothing()
        }

        stub(state) { stub in
            when(stub.stakingOption.get).thenReturn(Multistaking.ChainAssetOption(chainAsset: chainAsset, type: .subtensor))
            when(stub.selectedAccount.get).thenReturn(account)
            when(stub.positionsSyncService.get).thenReturn(nil)
            when(stub.rootClaimableService.get).thenReturn(nil)
            when(stub.subnetsService.get).thenReturn(subnetsService)
            when(stub.setup(for: any())).thenDoNothing()
            when(stub.throttle()).thenDoNothing()
        }

        return state
    }

    private final class CapturedViewModels {
        var last: SubtensorPortfolioViewModel?

        var lastHeader: SubtensorPortfolioHeaderViewModel? {
            guard case let .positions(header, _) = last?.content else {
                return nil
            }

            return header
        }

        var lastEmpty: SubtensorPortfolioEmptyViewModel? {
            guard case let .empty(viewModel) = last?.content else {
                return nil
            }

            return viewModel
        }
    }

    private func capture(_ view: MockSubtensorPortfolioViewProtocol) -> CapturedViewModels {
        let viewModels = CapturedViewModels()

        stub(view) { stub in
            when(stub.didReceive(viewModel: any())).then { viewModels.last = $0 }
        }

        return viewModels
    }

    private func makeInteractor() -> MockSubnetPortfolioInteractorInputProtocol {
        let interactor = MockSubnetPortfolioInteractorInputProtocol()

        stub(interactor) { stub in
            when(stub.cachedSnapshot()).thenReturn(SubtensorPortfolioSnapshot(catalogue: .miss, rootRate: .miss))
            when(stub.loadWeeklyChanges(for: any())).thenDoNothing()
            when(stub.loadHistories(for: any())).thenDoNothing()
        }

        return interactor
    }

    private func makePresenter(
        interactor: MockSubnetPortfolioInteractorInputProtocol,
        view: MockSubtensorPortfolioViewProtocol,
        currencyManager: CurrencyManagerStub
    ) -> SubtensorPortfolioPresenter {
        let chainAsset = SubtensorFlowChainWorld.chainAsset()

        let presenter = SubtensorPortfolioPresenter(
            interactor: interactor,
            wireframe: MockSubtensorPortfolioWireframeProtocol(),
            viewModelFactory: SubtensorPortfolioViewModelFactory(
                chainAsset: chainAsset,
                priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
            ),
            account: SubtensorFlowChainWorld.coldkeyAccount(),
            chainAsset: chainAsset,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return presenter
    }

    private func makeRootState(stake: Balance) -> Multistaking.SubtensorStakingState {
        Multistaking.SubtensorStakingState(
            positions: [
                SubtensorStakingPosition(
                    hotkey: Data(repeating: 7, count: 32),
                    netuid: SubtensorStakingPallet.rootNetuid,
                    stakeAlpha: stake,
                    hotkeyEmissionPerTempo: 0,
                    totalHotkeyAlpha: nil,
                    isRegistered: true
                )
            ],
            prices: [:]
        )
    }

    private func makeYieldService() -> MockSubtensorYieldServiceProtocol {
        let yieldService = MockSubtensorYieldServiceProtocol()

        stub(yieldService) { stub in
            when(stub.createRootYieldWrapper()).thenReturn(CompoundOperationWrapper.createWithResult(nil))
            when(stub.createAlphaYieldsWrapper(for: any())).thenReturn(
                CompoundOperationWrapper.createWithError(CommonError.dataCorruption)
            )
            when(stub.cachedAlphaYields(for: any())).thenReturn(.miss)
        }

        return yieldService
    }

    private func makeSubnetLogosProvider() -> MockSubtensorSubnetLogosProviderProtocol {
        let subnetLogosProvider = MockSubtensorSubnetLogosProviderProtocol()

        stub(subnetLogosProvider) { stub in
            when(stub.createLogosWrapper()).thenReturn(CompoundOperationWrapper.createWithError(CommonError.dataCorruption))
        }

        return subnetLogosProvider
    }

    private func makeEventCenter() -> MockEventCenterProtocol {
        let eventCenter = MockEventCenterProtocol()

        stub(eventCenter) { stub in
            when(stub.add(observer: any(), dispatchIn: any())).thenDoNothing()
        }

        return eventCenter
    }

    private func openAndLeavePosition(on state: SubtensorStakingSharedStateProtocol) {
        weak var leftPosition: SubtensorPositionInteractor?

        do {
            let interactor = SubtensorPositionInteractor(
                state: state,
                netuid: 64,
                catalogueService: makeCatalogueService(),
                yieldService: makeYieldService(),
                subnetLogosProvider: makeSubnetLogosProvider(),
                priceHistoryStore: .init(
                    priceHistoryService: nil,
                    historyCache: SubtensorPriceHistoryCache(),
                    operationQueue: OperationQueue()
                ),
                validatorFactory: SubtensorValidatorPresetFactory(
                    directoryService: makeDirectoryService(),
                    recommendationService: MockSubtensorRecommendationServiceProtocol(),
                    operationQueue: OperationQueue(),
                    logger: Logger.shared
                ),
                rootHoldFactory: MockSubtensorRootHoldFactoryProtocol(),
                priceLocalSubscriptionFactory: PriceProviderFactoryStub(),
                currencyManager: CurrencyManagerStub(),
                operationQueue: OperationQueue(),
                logger: Logger.shared
            )

            let presenter = SubtensorPositionPresenter(
                group: SubtensorPortfolioGroup(
                    netuid: 64,
                    positions: [],
                    totalAlpha: 0,
                    redeemable: 0,
                    taoValue: nil,
                    availability: nil,
                    primaryHotkey: Data(repeating: 7, count: 32)
                ),
                account: state.selectedAccount,
                chainAsset: state.stakingOption.chainAsset,
                pendingRootClaims: SubtensorPendingRootClaims(),
                interactor: interactor,
                wireframe: SubtensorPositionWireframe(state: state),
                viewModelFactory: SubtensorPositionViewModelFactory(
                    chainAsset: state.stakingOption.chainAsset,
                    priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())
                ),
                localizationManager: LocalizationManager.shared
            )

            interactor.presenter = presenter
            presenter.setup()
            leftPosition = interactor
        }

        wait(for: [expectation(for: NSPredicate { _, _ in leftPosition == nil }, evaluatedWith: nil)], timeout: 10)
    }

    private func makeCatalogueService() -> MockSubtensorSubnetCatalogueServiceProtocol {
        let catalogueService = MockSubtensorSubnetCatalogueServiceProtocol()

        stub(catalogueService) { stub in
            when(stub.createCatalogueWrapper()).thenReturn(
                CompoundOperationWrapper.createWithError(CommonError.dataCorruption)
            )
            when(stub.cachedCatalogue()).thenReturn(.miss)
        }

        return catalogueService
    }

    private func makeDirectoryService() -> MockSubtensorValidatorDirectoryServiceProtocol {
        let directoryService = MockSubtensorValidatorDirectoryServiceProtocol()

        stub(directoryService) { stub in
            when(stub.createDirectoryWrapper(for: any())).thenReturn(
                CompoundOperationWrapper.createWithError(CommonError.dataCorruption)
            )
            when(stub.createDetailWrapper(for: any(), subnet: any())).thenReturn(
                CompoundOperationWrapper.createWithError(CommonError.dataCorruption)
            )
        }

        return directoryService
    }

    private func registeredObserver(in eventCenter: MockEventCenterProtocol) throws -> EventVisitorProtocol {
        let captor = ArgumentCaptor<EventVisitorProtocol>()

        verify(eventCenter).add(observer: captor.capture(), dispatchIn: any())

        return try XCTUnwrap(captor.value)
    }
}
