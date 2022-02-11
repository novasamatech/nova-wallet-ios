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

        let presenter = DAppSearchPresenter(
            wireframe: wireframe,
            initialQuery: "",
            delegate: delegate
        )

        presenter.view = view

        // when (setup test)

        let querySetupExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didReceive(initialQuery: any()).then { _ in
                querySetupExpectation.fulfill()
            }
        }

        presenter.setup()

        // then (setup test)

        wait(for: [querySetupExpectation], timeout: 10.0)

        // when (search test)

        stub(view) { stub in
            when(stub).didReceive(initialQuery: any()).thenDoNothing()
        }

        let expectedSearchString = "test"

        presenter.updateSearch(query: expectedSearchString)

        // when (query selection test)

        let selectionExpectation = XCTestExpectation()
        let closeExpectation = XCTestExpectation()

        stub(delegate) { stub in
            when(stub).didCompleteDAppSearchResult(any()).then { result in
                if case let .query(string) = result, string == expectedSearchString {
                    selectionExpectation.fulfill()
                }
            }
        }

        stub(wireframe) { stub in
            when(stub).close(from: any()).then { _ in
                closeExpectation.fulfill()
            }
        }

        presenter.selectSearchQuery()

        // then (query selection test)

        wait(for: [selectionExpectation, closeExpectation], timeout: 10.0)
    }
}
