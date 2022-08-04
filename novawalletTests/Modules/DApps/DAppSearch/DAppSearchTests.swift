import XCTest
@testable import novawallet
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

        let presenter = DAppSearchPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: DAppListViewModelFactory(),
            initialQuery: "",
            delegate: delegate
        )

        presenter.view = view
        interactor.presenter = presenter

        // when (setup test)

        let querySetupExpectation = XCTestExpectation()
        let dAppSetupExpectatation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didReceive(initialQuery: any()).then { _ in
                querySetupExpectation.fulfill()
            }

            when(stub).didReceiveDApp(viewModels: any()).then { viewModels in
                if !viewModels.isEmpty {
                    dAppSetupExpectatation.fulfill()
                }
            }
        }

        presenter.setup()

        // then (setup test)

        wait(for: [querySetupExpectation, dAppSetupExpectatation], timeout: 10.0)

        // when (search test)

        let dAppName = dAppList.dApps.last!.name

        let dAppSearchExpectation = XCTestExpectation()

        var selectedDApp: DAppViewModel?

        stub(view) { stub in
            when(stub).didReceive(initialQuery: any()).thenDoNothing()

            when(stub).didReceiveDApp(viewModels: any()).then { viewModels in
                if let dApp = viewModels.last {
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
            when(stub).didCompleteDAppSearchResult(any()).then { result in
                if case .dApp = result {
                    dAppSelectionExpectation.fulfill()
                }
            }
        }

        stub(wireframe) { stub in
            when(stub).close(from: any()).then { _ in
                dAppSelectionCloseExpectation.fulfill()
            }
        }

        presenter.selectDApp(viewModel: selectedDApp!)

        // then (dApp selection test)

        wait(for: [dAppSelectionExpectation, dAppSelectionCloseExpectation], timeout: 10.0)

        // when (query selection test)

        let querySelectionExpectation = XCTestExpectation()
        let querySelectionCloseExpectation = XCTestExpectation()

        stub(delegate) { stub in
            when(stub).didCompleteDAppSearchResult(any()).then { result in
                if case .query = result {
                    querySelectionExpectation.fulfill()
                }
            }
        }

        stub(wireframe) { stub in
            when(stub).close(from: any()).then { _ in
                querySelectionCloseExpectation.fulfill()
            }
        }

        presenter.selectSearchQuery()

        // then (dApp selection test)

        wait(for: [querySelectionExpectation, querySelectionCloseExpectation], timeout: 10.0)
    }
}
