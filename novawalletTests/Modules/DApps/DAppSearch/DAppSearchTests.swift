import XCTest
@testable import novawallet
import Foundation_iOS
import Cuckoo

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

        var bannerVisibility: [Bool] = []
        var completions: [Completion] = []

        init(dApps: [DApp], initialQuery: String?) {
            let view = MockDAppSearchViewProtocol()
            let wireframe = MockDAppSearchWireframeProtocol()
            let delegate = MockDAppSearchDelegate()
            let interactor = MockDAppSearchInteractorInputProtocol()

            let viewModelFactory = DAppListViewModelFactory(
                dappCategoriesViewModelFactory: DAppCategoryViewModelFactory(),
                dappIconViewModelFactory: DAppIconViewModelFactory()
            )

            self.view = view
            self.wireframe = wireframe
            self.delegate = delegate

            presenter = DAppSearchPresenter(
                interactor: interactor,
                wireframe: wireframe,
                viewModelFactory: viewModelFactory,
                initialQuery: initialQuery,
                selectedCategoryId: nil,
                delegate: delegate,
                applicationConfig: ApplicationConfig.shared,
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
