import Foundation_iOS
@testable import novawallet
import XCTest

final class SubtensorValidatorSelectPresenterTests: XCTestCase {
    private let hotkeyA = Data(repeating: 1, count: 32)
    private let hotkeyB = Data(repeating: 2, count: 32)

    func testUnusualApyFilterIsDroppedWhenNoListedValidatorIsRecommended() {
        // given
        let fixture = makeFixture()

        // when
        fixture.presenter.setup()
        fixture.presenter.didReceive(directory: makeDirectory(fixture.target))
        fixture.presenter.didReceive(verification: makeVerification(recommended: []))

        // then
        XCTAssertEqual(fixture.view.loadedRows?.map(\.hotkey), [hotkeyA, hotkeyB])
        XCTAssertEqual(fixture.view.isFilterActive, false)
    }

    func testUnusualApyFilterKeepsOnlyRecommendedValidators() {
        // given
        let fixture = makeFixture()

        // when
        fixture.presenter.setup()
        fixture.presenter.didReceive(directory: makeDirectory(fixture.target))
        fixture.presenter.didReceive(verification: makeVerification(recommended: [hotkeyB]))

        // then
        XCTAssertEqual(fixture.view.loadedRows?.map(\.hotkey), [hotkeyB])
        XCTAssertEqual(fixture.view.isFilterActive, true)
    }

    func testDroppedFilterIsShownAsInactiveInFiltersWhileSessionPreferenceIsKept() throws {
        // given
        let fixture = makeFixture()

        fixture.presenter.setup()
        fixture.presenter.didReceive(directory: makeDirectory(fixture.target))
        fixture.presenter.didReceive(verification: makeVerification(recommended: []))

        // when
        fixture.presenter.showSortOptions()

        // then
        XCTAssertEqual(fixture.wireframe.appliedFilters?.hidesUnusualApy, false)

        // when the user only changes the sort in the sheet
        var draft = try XCTUnwrap(fixture.wireframe.appliedFilters)
        draft.sort = .name
        fixture.wireframe.onApply?(draft)

        // then the shared preference still hides unusual apy for the next subnet
        XCTAssertEqual(fixture.filterSession.applied(isRoot: false).sort, .name)
        XCTAssertEqual(fixture.filterSession.applied(isRoot: false).hidesUnusualApy, true)
    }
}

private extension SubtensorValidatorSelectPresenterTests {
    struct Fixture {
        let target: SubtensorStakeTarget
        let view: ViewStub
        let wireframe: WireframeStub
        let delegate: DelegateStub
        let filterSession: SubtensorValidatorFilterSession
        let presenter: SubtensorValidatorSelectPresenter
    }

    final class ViewStub: SubtensorValidatorSelectViewProtocol {
        let controller = UIViewController()
        let isSetup = true

        private(set) var isFilterActive: Bool?
        private(set) var states: [SubtensorValidatorListState] = []

        var loadedRows: [SubtensorValidatorRowViewModel]? {
            if case let .loaded(viewModel) = states.last {
                return viewModel.rows
            }

            return nil
        }

        func didReceive(header _: SubtensorValidatorListHeaderViewModel, isFilterActive: Bool) {
            self.isFilterActive = isFilterActive
        }

        func didReceive(state: SubtensorValidatorListState) {
            states.append(state)
        }
    }

    final class InteractorStub: SubtensorValidatorSelectInteractorInputProtocol {
        func setup() {}
        func retry() {}
    }

    final class WireframeStub: SubtensorValidatorSelectWireframeProtocol {
        var state: SubtensorSharedStateProtocol { fatalError("not used by the presenter tests") }

        private(set) var appliedFilters: SubtensorValidatorFilters?
        private(set) var onApply: ((SubtensorValidatorFilters) -> Void)?

        func showFilters(
            from _: SubtensorValidatorSelectViewProtocol?,
            applied: SubtensorValidatorFilters,
            onApply: @escaping (SubtensorValidatorFilters) -> Void
        ) {
            appliedFilters = applied
            self.onApply = onApply
        }

        func complete(from _: SubtensorValidatorSelectViewProtocol?) {}
    }

    final class DelegateStub: SubtensorValidatorSelectDelegate {
        func didSelectValidator(_: SubtensorValidatorDirectoryItem, for _: SubtensorStakeTarget) {}
    }

    func makeFixture() -> Fixture {
        let target = SubtensorStakeTarget.subnet(
            info: SubtensorPallet.DynamicInfo(netuid: 92, taoInEmission: 0, networkRegisteredAt: 9_247_819),
            price: 1_000_000_000
        )

        let view = ViewStub()
        let wireframe = WireframeStub()
        let filterSession = SubtensorValidatorFilterSession()
        let delegate = DelegateStub()

        let listFactory = SubtensorValidatorListFactory(
            chainFormat: .substrate(42),
            assetDisplayInfo: AssetBalanceDisplayInfo(
                displayPrecision: 4,
                assetPrecision: 9,
                symbol: "TAO",
                symbolValueSeparator: " ",
                symbolPosition: .suffix,
                icon: nil
            )
        )

        let presenter = SubtensorValidatorSelectPresenter(
            target: target,
            selectedHotkey: nil,
            interactor: InteractorStub(),
            wireframe: wireframe,
            listFactory: listFactory,
            delegate: delegate,
            localizationManager: LocalizationManager.shared,
            filterSession: filterSession
        )

        presenter.view = view

        return Fixture(
            target: target,
            view: view,
            wireframe: wireframe,
            delegate: delegate,
            filterSession: filterSession,
            presenter: presenter
        )
    }

    func makeDirectory(_ target: SubtensorStakeTarget) -> SubtensorValidatorDirectory {
        SubtensorValidatorDirectory(
            subnet: target.subnetRef,
            items: [hotkeyA, hotkeyB].map {
                SubtensorValidatorDirectoryItem(
                    hotkey: $0,
                    netuid: target.netuid,
                    name: nil,
                    take: nil,
                    reportedStake: nil,
                    status: nil
                )
            },
            listStamp: nil,
            isPartial: false
        )
    }

    func makeVerification(recommended: Set<AccountId>) -> SubtensorValidatorListVerification {
        SubtensorValidatorListVerification(takes: [:], recommended: .success(recommended))
    }
}
