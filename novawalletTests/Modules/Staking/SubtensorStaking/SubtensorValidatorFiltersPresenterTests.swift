@testable import novawallet
import XCTest
import UIKit

final class SubtensorValidatorFiltersPresenterTests: XCTestCase {
    func testDraftApplyResetCancelAndUnsupportedActions() {
        let view = FiltersView()
        let wireframe = FiltersWireframe()
        var applied: [SubtensorValidatorFilters] = []
        let presenter = SubtensorValidatorFiltersPresenter(
            applied: .supportedDefault, interactor: SubtensorValidatorFiltersInteractor(),
            wireframe: wireframe, onApply: { applied.append($0) }
        )
        presenter.view = view
        presenter.setup()
        XCTAssertFalse(view.model?.canApply ?? true)
        XCTAssertFalse(view.model?.canReset ?? true)
        presenter.selectSort(.apy)
        presenter.setHidesUnusualApy(true)
        XCTAssertEqual(view.model?.selectedSort, .totalStaked)
        XCTAssertFalse(view.model?.canApply ?? true)
        presenter.selectSort(.name)
        XCTAssertTrue(applied.isEmpty)
        XCTAssertTrue(view.model?.canApply ?? false)
        presenter.reset()
        XCTAssertFalse(view.model?.canApply ?? true)
        presenter.selectSort(.name)
        presenter.apply()
        presenter.apply()
        XCTAssertEqual(applied, [.init(sort: .name)])
        XCTAssertEqual(wireframe.completions, 1)
    }

    func testSessionSeparatesLanesAndReopenCopiesAppliedValue() {
        let session = SubtensorValidatorFilterSession()
        session.apply(.init(sort: .name), isRoot: false)
        XCTAssertEqual(session.applied(isRoot: true), .supportedDefault)
        let view = FiltersView()
        let presenter = SubtensorValidatorFiltersPresenter(
            applied: session.applied(isRoot: false), interactor: SubtensorValidatorFiltersInteractor(),
            wireframe: FiltersWireframe(), onApply: { session.apply($0, isRoot: false) }
        )
        presenter.view = view
        presenter.setup()
        XCTAssertEqual(view.model?.selectedSort, .name)
        presenter.reset()
        XCTAssertEqual(session.applied(isRoot: false).sort, .name)
        XCTAssertTrue(view.model?.canApply ?? false)
        XCTAssertFalse(view.model?.canReset ?? true)
        session.apply(.init(sort: .apy, hidesUnusualApy: true), isRoot: true)
        XCTAssertEqual(session.applied(isRoot: true), .supportedDefault)
    }
}

private final class FiltersView: UIViewController, SubtensorValidatorFiltersViewProtocol {
    var model: SubtensorValidatorFiltersViewModel?
    func didReceive(_ viewModel: SubtensorValidatorFiltersViewModel) { model = viewModel }
}

private final class FiltersWireframe: ValidatorFiltersWireframeProtocol {
    var completions = 0
    func complete(from _: SubtensorValidatorFiltersViewProtocol?) { completions += 1 }
}
