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
            when(stub).didReceive(initialQuery: any()).then { _ in
                querySetupExpectation.fulfill()
            }

            when(stub).didReceive(viewModel: any()).then { viewModel in
                if viewModel?.dApps.isEmpty == false {
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

            when(stub).didReceive(viewModel: any()).then { viewModel in
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
    }
}
