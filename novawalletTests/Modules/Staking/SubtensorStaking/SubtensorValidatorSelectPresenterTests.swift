import BigInt
import Cuckoo
import Foundation_iOS
@testable import novawallet
import XCTest

final class SubtensorValidatorSelectPresenterTests: XCTestCase {
    func testApplyPreservesSearchSelectionAndSurvivesSelectorRecreation() throws {
        let session = SubtensorValidatorFilterSession()
        let first = makeSetup(session: session)
        first.presenter.setup()
        first.presenter.didReceive(directory: directory())
        first.presenter.didReceive(clientGates: gates)
        first.presenter.select(hotkey: Data(repeating: 1, count: 32))
        first.presenter.search("Zulu")
        first.presenter.showSortOptions()
        let apply = ArgumentCaptor<(SubtensorValidatorFilters) -> Void>()
        verify(first.wireframe).showFilters(from: any(), applied: equal(to: .supportedDefault), onApply: apply.capture())
        XCTAssertEqual(session.applied(isRoot: false), .supportedDefault)
        try XCTUnwrap(apply.value)(SubtensorValidatorFilters(sort: .name, hidesUnusualApy: false))
        let model = try lastList(first.view)
        XCTAssertEqual(model.rows.map(\.title), ["Zulu"])
        XCTAssertTrue(model.rows[0].isSelected)
        XCTAssertTrue(model.canSelect)
        XCTAssertTrue(model.countTitle.contains("1 OF 2"))
        XCTAssertEqual(session.applied(isRoot: true), .supportedDefault)
        let second = makeSetup(session: session)
        second.presenter.setup()
        let header = ArgumentCaptor<SubtensorValidatorListHeaderViewModel>()
        verify(second.view).didReceive(header: header.capture(), isFilterActive: equal(to: true))
        XCTAssertTrue(try XCTUnwrap(header.value).sortTitle.contains("NAME"))
    }

    func testOptionalRatesDoNotBlockResolvedListAndFailuresClearCountsKeepFilterTint() throws {
        let session = SubtensorValidatorFilterSession()
        session.apply(.init(sort: .name, hidesUnusualApy: false), isRoot: false)
        let setup = makeSetup(session: session)
        setup.presenter.setup()
        setup.presenter.didReceive(directory: directory())
        setup.presenter.didReceive(clientGates: gates)
        XCTAssertEqual(try lastList(setup.view).rows.count, 2)
        setup.presenter.didFailDirectory(NSError(domain: "fixture", code: 1))
        let headers = ArgumentCaptor<SubtensorValidatorListHeaderViewModel>()
        verify(setup.view, atLeastOnce()).didReceive(header: headers.capture(), isFilterActive: equal(to: true))
        XCTAssertEqual(headers.allValues.last?.countTitle, "VALIDATORS: — OF —")
        let states = ArgumentCaptor<SubtensorValidatorListState>()
        verify(setup.view, atLeastOnce()).didReceive(state: states.capture())
        guard case .failed = states.allValues.last else { return XCTFail("Expected failure") }
        setup.presenter.retry()
        verify(setup.interactor).retry()
    }

    func testReusedRegistrationDirectoryCannotPopulateSelector() {
        let setup = makeSetup(session: .init())
        setup.presenter.setup()
        setup.presenter.didReceive(clientGates: gates)
        setup.presenter.didReceive(directory: directory(registeredAt: 101))
        let states = ArgumentCaptor<SubtensorValidatorListState>()
        verify(setup.view, atLeastOnce()).didReceive(state: states.capture())
        guard case .loading = states.allValues.last else { return XCTFail("Expected loading") }
    }

    private let gates = SubtensorClientGates(maxTake: BigRational(numerator: 18, denominator: 100), requirePermit: false, requireActiveWithinCutoff: false)

    private func directory(registeredAt: UInt64 = 100) -> SubtensorValidatorDirectory {
        .init(subnet: .init(netuid: 1, registeredAt: registeredAt), items: [(1, "Zulu"), (2, "Alpha")].map { id, name in
            .init(
                hotkey: Data(repeating: UInt8(id), count: 32),
                netuid: 1,
                name: name,
                take: 0.1,
                reportedStake: BigRational(numerator: BigUInt(id), denominator: 1),
                status: .init(uid: UInt16(id), hasPermit: true, blocksSinceUpdate: 1, isActive: true)
            )
        }, listStamp: nil, isPartial: false, isEnrichmentTruncated: false, chainBlock: 200)
    }

    private func lastList(_ view: MockSubtensorValidatorSelectViewProtocol) throws -> SubtensorValidatorListViewModel {
        let states = ArgumentCaptor<SubtensorValidatorListState>()
        verify(view, atLeastOnce()).didReceive(state: states.capture())
        guard case let .loaded(value) = states.allValues.last else { throw NSError(domain: "missing list", code: 1) }
        return value
    }

    private struct Setup {
        let presenter: SubtensorValidatorSelectPresenter
        let view: MockSubtensorValidatorSelectViewProtocol
        let interactor: MockValidatorSelectInteractorInputProtocol
        let wireframe: MockValidatorSelectWireframeProtocol
        let delegate: SelectionDelegate
    }

    private func makeSetup(session: SubtensorValidatorFilterSession) -> Setup {
        let view = MockSubtensorValidatorSelectViewProtocol()
        let interactor = MockValidatorSelectInteractorInputProtocol()
        let wireframe = MockValidatorSelectWireframeProtocol()
        let delegate = SelectionDelegate()
        stub(view) { stub in
            when(stub.isSetup.get).thenReturn(true)
            when(stub.didReceive(header: any(), isFilterActive: any())).thenDoNothing()
            when(stub.didReceive(state: any())).thenDoNothing()
        }
        stub(interactor) { stub in
            when(stub.cachedSnapshot()).thenReturn(.init(directory: .miss, clientGates: .miss, yields: .miss, alphaPrice: .miss))
            when(stub.setup()).thenDoNothing()
            when(stub.retry()).thenDoNothing()
        }
        stub(wireframe) { stub in when(stub.showFilters(from: any(), applied: any(), onApply: any())).thenDoNothing() }
        let info = AssetBalanceDisplayInfo(displayPrecision: 5, assetPrecision: 9, symbol: "TAO", symbolValueSeparator: " ", symbolPosition: .suffix, icon: nil)
        let presenter = SubtensorValidatorSelectPresenter(
            target: .subnet(info: SubtensorSubnetParametersTests.subnet(), price: 1), selectedHotkey: nil,
            interactor: interactor, wireframe: wireframe,
            listFactory: .init(chainFormat: .substrate(42), assetDisplayInfo: info), delegate: delegate,
            localizationManager: LocalizationManager.shared, logger: Logger.shared, filterSession: session
        )
        presenter.view = view
        return .init(presenter: presenter, view: view, interactor: interactor, wireframe: wireframe, delegate: delegate)
    }
}

private final class SelectionDelegate: SubtensorValidatorSelectDelegate {
    func didSelectValidator(_: SubtensorValidatorDirectoryItem, for _: SubtensorStakeTarget) {}
}
