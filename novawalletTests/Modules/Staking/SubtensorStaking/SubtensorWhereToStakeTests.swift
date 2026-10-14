import Cuckoo
import Foundation_iOS
@testable import novawallet
import XCTest

final class SubtensorWhereToStakeTests: XCTestCase {
    func testCarouselOrderBoundsAndUnavailableApy() {
        let wireframe = Wireframe()
        let presenter = SubtensorWhereToStakePresenter(
            interactor: SubtensorWhereToStakeInteractor(),
            wireframe: wireframe,
            viewModelFactory: .init(),
            localizationManager: LocalizationManager.shared
        )
        XCTAssertEqual(presenter.interactor.orders, [.poolSize, .age, .apy, .root])
        presenter.movePage(by: -1)
        XCTAssertEqual(presenter.page, 0)
        presenter.movePage(by: 99)
        XCTAssertEqual(presenter.page, 3)
        presenter.choose(.apy)
        XCTAssertTrue(wireframe.orders.isEmpty)
        presenter.choose(.root)
        presenter.choose(.poolSize)
        presenter.choose(.poolSize)
        XCTAssertEqual(wireframe.orders, [.root, .poolSize, .poolSize])
    }

    func testCardCopyAndDisabledStateAreHonestAboutUnavailableData() {
        let factory = SubtensorWhereToStakeViewModelFactory()
        let root = factory.create(order: .root, locale: Locale(identifier: "en"))
        XCTAssertTrue(root.cons.isEmpty)
        XCTAssertNil(root.unavailable)
        let apy = factory.create(order: .apy, locale: Locale(identifier: "en"))
        XCTAssertEqual(apy.unavailable, "APY ordering is unavailable")
        XCTAssertEqual(factory.create(order: .poolSize, locale: Locale(identifier: "en")).title, "Pool size")
    }

    func testRootRowRemainsFirstInLoadingErrorAndEmptyStates() {
        let presenter = MockSubtensorSubnetSelectPresenterProtocol()
        stub(presenter) { stub in
            when(stub.setup()).thenDoNothing()
            when(stub.selectRoot()).thenDoNothing()
        }
        let view = SubtensorSubnetSelectViewController(presenter: presenter, localizationManager: LocalizationManager.shared)
        view.loadViewIfNeeded()
        let contents: [SubtensorSubnetListViewModel.Content] = [
            .loading, .empty("Nothing found"),
            .failed(.init(title: "Unavailable", details: "Retry", retryTitle: "Retry"))
        ]
        for content in contents {
            view.didReceive(list: .init(chipTitle: "Age", caption: nil, isFilterActive: false, areControlsEnabled: false, content: content))
            XCTAssertEqual(view.tableView(view.rootView.tableView, numberOfRowsInSection: 0), 1)
            let first = view.tableView(view.rootView.tableView, cellForRowAt: IndexPath(row: 0, section: 0))
            XCTAssertEqual(first.textLabel?.text, "Stake to root")
            view.tableView(view.rootView.tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
        }
        verify(presenter, times(3)).selectRoot()
    }

    private final class Wireframe: SubtensorWhereToStakeWireframeProtocol {
        var orders: [SubtensorQuickPickOrder] = []
        func showSetup(from _: SubtensorWhereToStakeViewProtocol?, order: SubtensorQuickPickOrder) { orders.append(order) }
    }
}
