import XCTest
@testable import novawallet
import Foundation_iOS
import Cuckoo
import NovaAnalytics

class DAppSearchTests: XCTestCase {
    func testSetupAndSearch() {
        // given

        let view = MockDAppSearchViewProtocol()
        let wireframe = MockDAppSearchWireframeProtocol()
        let delegate = MockDAppSearchDelegate()

        let dAppList = DAppListGenerator.createAnyDAppList()
        let dAppProvider = SingleValueProviderStub(
            item: dAppList
        )

        let dAppProviderFactory = DAppLocalSubscriptionFactory(
            storageFacade: UserDataStorageTestFacade(),
            operationQueue: OperationQueue(),
            logger: nil
        )

        let interactor = DAppSearchInteractor(
            dAppProvider: AnySingleValueProvider(dAppProvider),
            dAppsLocalSubscriptionFactory: dAppProviderFactory,
            logger: Logger.shared
        )

        let viewModelFactory = DAppListViewModelFactory(
            dappCategoriesViewModelFactory: DAppCategoryViewModelFactory(),
            dappIconViewModelFactory: DAppIconViewModelFactory()
        )

        let presenter = DAppSearchPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            initialQuery: "",
            selectedCategoryId: nil,
            delegate: delegate,
            applicationConfig: ApplicationConfig.shared,
            analyticsTracker: AnalyticsTrackerSpy(),
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        // when (setup test)

        let querySetupExpectation = XCTestExpectation()
        let dAppSetupExpectatation = XCTestExpectation()

        stub(view) { stub in
            when(stub.didReceive(initialQuery: any())).then { _ in
                querySetupExpectation.fulfill()
            }

            when(stub.didReceive(viewModel: any())).then { viewModel in
                if viewModel?.dApps.isEmpty == false {
                    dAppSetupExpectatation.fulfill()
                }
            }

            when(stub.didReceive(stakingBannerVisible: any())).thenDoNothing()
        }

        presenter.setup()

        // then (setup test)

        wait(for: [querySetupExpectation, dAppSetupExpectatation], timeout: 10.0)

        // when (search test)

        let dAppName = dAppList.dApps.last!.name

        let dAppSearchExpectation = XCTestExpectation()

        var selectedDApp: DAppViewModel?

        stub(view) { stub in
            when(stub.didReceive(initialQuery: any())).thenDoNothing()

            when(stub.didReceive(viewModel: any())).then { viewModel in
                if let dApp = viewModel?.dApps.last {
                    selectedDApp = dApp
                    dAppSearchExpectation.fulfill()
                }
            }
        }

        presenter.updateSearch(query: dAppName)

        // then (search test)

        wait(for: [dAppSearchExpectation], timeout: 10.0)

        // when (dApp selection test)

        let dAppSelectionExpectation = XCTestExpectation()
        let dAppSelectionCloseExpectation = XCTestExpectation()

        stub(delegate) { stub in
            when(stub.didCompleteDAppSearchResult(any(), noticeContext: any())).then { result, _ in
                if case .dApp = result {
                    dAppSelectionExpectation.fulfill()
                }
            }
        }

        stub(wireframe) { stub in
            when(stub.close(from: any(), completion: any())).then { _, completion in
                dAppSelectionCloseExpectation.fulfill()
                completion?()
            }
        }

        presenter.selectDApp(viewModel: selectedDApp!)

        // then (dApp selection test)

        wait(for: [dAppSelectionExpectation, dAppSelectionCloseExpectation], timeout: 10.0)
    }

    func testCatalogueDAppOnBittensorHostCompletesWithBittensorNotice() {
        // given
        let taoDApp = makeDApp(name: "TAO App", url: "https://www.tao.app", categories: ["staking"])
        let setup = makeSetup(dApps: [taoDApp])

        // when
        setup.presenter.selectDApp(viewModel: makeViewModel(for: taoDApp))

        // then
        XCTAssertEqual(setup.completions.count, 1)
        XCTAssertEqual(setup.completions.first?.result.dApp, taoDApp)
        XCTAssertEqual(setup.completions.first?.noticeContext?.kind, .bittensor)
        XCTAssertEqual(setup.completions.first?.noticeContext?.host?.stringValue, "www.tao.app")
    }

    func testStakingCategoryDAppCompletesWithStakingNotice() {
        // given
        let stakingDApp = makeDApp(name: "Omni", url: "https://omni.ls/app", categories: ["staking"])
        let setup = makeSetup(dApps: [stakingDApp])

        // when
        setup.presenter.selectDApp(viewModel: makeViewModel(for: stakingDApp))

        // then
        XCTAssertEqual(setup.completions.count, 1)
        XCTAssertEqual(setup.completions.first?.noticeContext?.kind, .thirdPartyStaking)
        XCTAssertEqual(setup.completions.first?.noticeContext?.host?.stringValue, "omni.ls")
    }

    func testOtherDAppCompletesWithoutNotice() {
        // given
        let dexDApp = makeDApp(name: "Hydration", url: "https://app.hydration.net", categories: ["dex"])
        let setup = makeSetup(dApps: [dexDApp])

        // when
        setup.presenter.selectDApp(viewModel: makeViewModel(for: dexDApp))

        // then
        XCTAssertEqual(setup.completions.count, 1)
        XCTAssertEqual(setup.completions.first?.result.dApp, dexDApp)
        XCTAssertNil(setup.completions.first?.noticeContext)
    }

    func testStakingBannerFollowsQuery() {
        // given
        let setup = makeSetup()

        // when
        setup.presenter.setup()

        for query in ["tao", "staking", "hydration", "TAO staking", ""] {
            setup.presenter.updateSearch(query: query)
        }

        // then
        XCTAssertEqual(setup.bannerVisibility, [false, true, true, false, true, false])
    }

    func testBittensorBannerIsTrackedOncePerAppearance() {
        // given
        let setup = makeSetup()
        let shownEvent = AnalyticsEvent.dappStakingPromptShown(
            placement: .searchBanner,
            kind: .bittensor,
            host: nil
        )

        setup.presenter.setup()

        // when
        for query in ["t", "ta", "tao", "taos"] {
            setup.presenter.updateSearch(query: query)
        }

        // then
        XCTAssertEqual(setup.promptEvents, [shownEvent])

        // when
        for query in ["", "tao"] {
            setup.presenter.updateSearch(query: query)
        }

        // then
        XCTAssertEqual(setup.promptEvents, [shownEvent, shownEvent])
    }

    func testBannerIsTrackedAgainWhenKindChanges() {
        // given
        let setup = makeSetup()

        setup.presenter.setup()

        // when
        for query in ["polkadot staking", "polkadot stakin", "tao staking", "tao", ""] {
            setup.presenter.updateSearch(query: query)
        }

        // then
        XCTAssertEqual(
            setup.promptEvents,
            [
                .dappStakingPromptShown(placement: .searchBanner, kind: .staking, host: nil),
                .dappStakingPromptShown(placement: .searchBanner, kind: .bittensor, host: nil)
            ]
        )
    }

    func testBannerForInitialQueryIsTracked() {
        // given
        let setup = makeSetup(initialQuery: "https://taostats.io/validators")

        // when
        setup.presenter.setup()

        // then
        XCTAssertEqual(setup.bannerVisibility, [true])
        XCTAssertEqual(
            setup.promptEvents,
            [.dappStakingPromptShown(placement: .searchBanner, kind: .bittensor, host: nil)]
        )
    }

    func testBannerEventsCarryNeitherQueryNorHost() {
        // given
        let setup = makeSetup()

        setup.presenter.setup()

        // when
        setup.presenter.updateSearch(query: "taostats.io")
        setup.presenter.activateStaking()

        // then
        XCTAssertEqual(setup.promptEvents.count, 2)

        for event in setup.promptEvents {
            XCTAssertTrue(
                Set(event.properties.keys).isSubset(of: [.placement, .kind, .action]),
                "\(event)"
            )
        }
    }

    func testActivateStakingForBittensorQueryOpensBittensorStaking() {
        // given
        let setup = makeSetup()

        setup.presenter.setup()
        setup.presenter.updateSearch(query: "TAO staking")

        // when
        setup.presenter.activateStaking()

        // then
        verify(setup.wireframe).redirectToBittensorStaking(
            from: any(),
            source: equal(to: StakingFlowSource.dappSearchBanner)
        )
        verify(setup.wireframe, never()).redirectToStaking(from: any())

        XCTAssertEqual(
            setup.promptEvents,
            [
                .dappStakingPromptShown(placement: .searchBanner, kind: .bittensor, host: nil),
                .dappStakingPromptAction(
                    placement: .searchBanner,
                    kind: .bittensor,
                    action: .goToStaking,
                    host: nil
                )
            ]
        )
    }

    func testActivateStakingForStakingQueryOpensStakingTab() {
        // given
        let setup = makeSetup()

        setup.presenter.setup()
        setup.presenter.updateSearch(query: "polkadot staking")

        // when
        setup.presenter.activateStaking()

        // then
        verify(setup.wireframe).redirectToStaking(from: any())
        verify(setup.wireframe, never()).redirectToBittensorStaking(from: any(), source: any())

        XCTAssertEqual(
            setup.promptEvents,
            [
                .dappStakingPromptShown(placement: .searchBanner, kind: .staking, host: nil),
                .dappStakingPromptAction(
                    placement: .searchBanner,
                    kind: .staking,
                    action: .goToStaking,
                    host: nil
                )
            ]
        )
    }

    func testBittensorAddressSkipsUnknownDAppWarning() {
        // given
        let setup = makeSetup()

        setup.presenter.setup()
        setup.presenter.updateSearch(query: "taoyield.com")

        // when
        setup.presenter.selectSearchQuery()

        // then
        XCTAssertTrue(setup.unknownWarningHandlers.isEmpty)
        XCTAssertEqual(setup.completions.count, 1)
        XCTAssertEqual(setup.completions.first?.result.queryString, "taoyield.com")
        XCTAssertEqual(setup.completions.first?.noticeContext?.kind, .bittensor)
        XCTAssertEqual(setup.completions.first?.noticeContext?.host?.stringValue, "taoyield.com")
    }

    func testUnknownAddressStillShowsWarning() {
        // given
        let setup = makeSetup()

        setup.presenter.setup()
        setup.presenter.updateSearch(query: "unknown-site.xyz")

        // when
        setup.presenter.selectSearchQuery()

        // then
        XCTAssertEqual(setup.unknownWarningHandlers.count, 1)
        XCTAssertTrue(setup.completions.isEmpty)

        // when
        setup.unknownWarningHandlers.first?()

        // then
        XCTAssertEqual(setup.completions.count, 1)
        XCTAssertEqual(setup.completions.first?.result.queryString, "unknown-site.xyz")
        XCTAssertNil(setup.completions.first?.noticeContext)
    }

    func testFreeTextBittensorQueryKeepsWarningAndHasNoNotice() {
        // given
        let setup = makeSetup()

        setup.presenter.setup()
        setup.presenter.updateSearch(query: "tao")

        // when
        setup.presenter.selectSearchQuery()

        // then
        XCTAssertEqual(setup.unknownWarningHandlers.count, 1)
        XCTAssertTrue(setup.completions.isEmpty)

        // when
        setup.unknownWarningHandlers.first?()

        // then
        XCTAssertEqual(setup.completions.count, 1)
        XCTAssertEqual(setup.completions.first?.result.queryString, "tao")
        XCTAssertNil(setup.completions.first?.noticeContext)
    }

    func testFreeTextMatchingCatalogueOpensWithoutWarningAndNotice() {
        // given
        let taoDApp = makeDApp(name: "TAO App", url: "https://www.tao.app", categories: ["staking"])
        let setup = makeSetup(dApps: [taoDApp])

        setup.presenter.setup()
        setup.presenter.updateSearch(query: "tao")

        // when
        setup.presenter.selectSearchQuery()

        // then
        XCTAssertTrue(setup.unknownWarningHandlers.isEmpty)
        XCTAssertEqual(setup.completions.count, 1)
        XCTAssertEqual(setup.completions.first?.result.queryString, "tao")
        XCTAssertNil(setup.completions.first?.noticeContext)
    }
}

// MARK: Private

private extension DAppSearchTests {
    struct Completion {
        let result: DAppSearchResult
        let noticeContext: DAppStakingNoticeContext?
    }

    final class Setup {
        let presenter: DAppSearchPresenter
        let view: MockDAppSearchViewProtocol
        let wireframe: MockDAppSearchWireframeProtocol
        let delegate: MockDAppSearchDelegate
        let tracker: AnalyticsTrackerSpy

        var bannerVisibility: [Bool] = []
        var completions: [Completion] = []
        var unknownWarningHandlers: [() -> Void] = []

        var promptEvents: [AnalyticsEvent] {
            tracker.events.filter { event in
                event.name == .dappStakingPromptShown || event.name == .dappStakingPromptAction
            }
        }

        init(dApps: [DApp], initialQuery: String?) {
            let view = MockDAppSearchViewProtocol()
            let wireframe = MockDAppSearchWireframeProtocol()
            let delegate = MockDAppSearchDelegate()
            let interactor = MockDAppSearchInteractorInputProtocol()
            let tracker = AnalyticsTrackerSpy()

            let viewModelFactory = DAppListViewModelFactory(
                dappCategoriesViewModelFactory: DAppCategoryViewModelFactory(),
                dappIconViewModelFactory: DAppIconViewModelFactory()
            )

            self.view = view
            self.wireframe = wireframe
            self.delegate = delegate
            self.tracker = tracker

            presenter = DAppSearchPresenter(
                interactor: interactor,
                wireframe: wireframe,
                viewModelFactory: viewModelFactory,
                initialQuery: initialQuery,
                selectedCategoryId: nil,
                delegate: delegate,
                applicationConfig: ApplicationConfig.shared,
                analyticsTracker: tracker,
                localizationManager: LocalizationManager.shared
            )

            presenter.view = view

            stub(interactor) { stub in
                when(stub.setup()).thenDoNothing()
            }

            stub(view) { stub in
                when(stub.didReceive(initialQuery: any())).thenDoNothing()
                when(stub.didReceive(viewModel: any())).thenDoNothing()
                when(stub.didReceive(stakingBannerVisible: any())).then { [weak self] isVisible in
                    self?.bannerVisibility.append(isVisible)
                }
            }

            stub(wireframe) { stub in
                when(stub.close(from: any(), completion: any())).then { _, completion in
                    completion?()
                }

                when(stub.redirectToStaking(from: any())).thenDoNothing()
                when(stub.redirectToBittensorStaking(from: any(), source: any())).thenDoNothing()

                when(
                    stub.showUnknownDappWarning(from: any(), email: any(), locale: any(), handler: any())
                ).then { [weak self] _, _, _, handler in
                    self?.unknownWarningHandlers.append(handler)
                }
            }

            stub(delegate) { stub in
                when(stub.didCompleteDAppSearchResult(any(), noticeContext: any())).then { [weak self] result, context in
                    self?.completions.append(Completion(result: result, noticeContext: context))
                }
            }

            presenter.didReceive(
                dAppsResult: .success(DAppList(popular: [], categories: [], dApps: dApps))
            )
            presenter.didReceiveFavorite(changes: [])
        }
    }

    func makeSetup(dApps: [DApp] = [], initialQuery: String? = nil) -> Setup {
        Setup(dApps: dApps, initialQuery: initialQuery)
    }

    func makeDApp(name: String, url: String, categories: [String]) -> DApp {
        DApp(
            name: name,
            url: URL(string: url)!,
            icon: nil,
            categories: categories,
            desktopOnly: nil
        )
    }

    func makeViewModel(for dApp: DApp) -> DAppViewModel {
        DAppViewModel(
            identifier: dApp.identifier,
            name: dApp.name,
            details: "",
            icon: nil,
            isFavorite: false
        )
    }
}

private extension DAppSearchResult {
    var queryString: String? {
        switch self {
        case let .query(string):
            return string
        case .dApp:
            return nil
        }
    }
}
