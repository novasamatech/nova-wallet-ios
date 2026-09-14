import Foundation_iOS
@testable import novawallet
import XCTest

final class TokensManageViewControllerTests: XCTestCase {
    func testNavigationBarContainsOnlyAddTokenAction() {
        // given

        let viewController = TokensManageViewController(
            presenter: PresenterStub(),
            localizationManager: LocalizationManager.shared
        )

        // when

        viewController.loadViewIfNeeded()

        // then

        XCTAssertEqual(viewController.navigationItem.rightBarButtonItems?.count, 1)
        XCTAssertTrue(
            viewController.navigationItem.rightBarButtonItems?.first === viewController.rootView.addTokenButton
        )
    }

    func testRootIdentifierDoesNotChangeWithExpansionState() {
        // given

        let collapsed = makeRootViewModel(groupId: "group", isExpanded: false)
        let expanded = makeRootViewModel(groupId: "group", isExpanded: true)

        // when

        let collapsedIdentifier = TokensManageListItem.root(collapsed).identifier
        let expandedIdentifier = TokensManageListItem.root(expanded).identifier

        // then

        XCTAssertEqual(collapsedIdentifier, expandedIdentifier)
    }
}

private extension TokensManageViewControllerTests {
    func makeRootViewModel(groupId: String, isExpanded: Bool) -> TokensManageRootViewModel {
        TokensManageRootViewModel(
            groupId: groupId,
            title: "Token",
            subtitle: "Network",
            imageViewModel: nil,
            iconShape: .circle,
            isOn: true,
            isExpandable: true,
            isExpanded: isExpanded,
            isPaused: false
        )
    }

    final class PresenterStub: TokensManagePresenterProtocol {
        func setup() {}
        func search(query _: String) {}
        func performAddToken() {}
        func performAutoAddChange(to _: Bool) {}
        func performExpand(for _: TokensManageRootViewModel) {}
        func performSwitch(for _: TokensManageRootViewModel, isOn _: Bool) {}
        func performSwitch(for _: TokensManageChildViewModel, isOn _: Bool) {}
    }
}

final class TokensManagePresenterTests: XCTestCase {
    func testGroupsAreSplitBetweenDefaultAndOtherSections() throws {
        // given

        let context = makeContext()
        let chains = [
            ChainModelGenerator.generateChain(generatingAssets: 2, addressPrefix: 0),
            ChainModelGenerator.generateChain(generatingAssets: 2, addressPrefix: 1)
        ]
        let defaultId = try XCTUnwrap(chains[0].chainAssets().first?.chainAssetId)

        // when

        prepare(context: context, chains: chains, defaults: [defaultId])

        // then

        let sections = try XCTUnwrap(context.view.updates.last?.sections)
        XCTAssertEqual(sections.map(\.kind), [.default, .others])
        XCTAssertEqual(rootGroupIds(in: sections[0]), [chains[0].chainId])
        XCTAssertEqual(rootGroupIds(in: sections[1]), [chains[1].chainId])
    }

    func testSearchReturnsOnlyMatchingMembersInResultsSection() throws {
        // given

        let context = makeContext()
        let chain = ChainModelGenerator.generateChain(generatingAssets: 2, addressPrefix: 0)
        prepare(context: context, chains: [chain], defaults: [])
        let matchingSymbol = try XCTUnwrap(chain.assets.sorted { $0.assetId < $1.assetId }.last?.symbol)

        // when

        context.view.updates = []
        context.presenter.search(query: matchingSymbol)

        // then

        let sections = try XCTUnwrap(context.view.updates.last?.sections)
        XCTAssertEqual(sections.map(\.kind), [.results])
        XCTAssertEqual(sections[0].items.count, 1)

        guard case let .root(root) = sections[0].items[0] else {
            return XCTFail("Expected a matching network root")
        }

        XCTAssertEqual(root.groupId, chain.chainId)
        XCTAssertFalse(root.isExpandable)
    }

    func testExpansionRequestsAnimatedRowsAndExpandedChevronState() throws {
        // given

        let context = makeContext()
        let chain = ChainModelGenerator.generateChain(generatingAssets: 2, addressPrefix: 0)
        prepare(context: context, chains: [chain], defaults: [])
        let root = try rootViewModel(from: XCTUnwrap(context.view.updates.last?.sections))

        // when

        context.view.updates = []
        context.presenter.performExpand(for: root)

        // then

        let update = try XCTUnwrap(context.view.updates.last)
        XCTAssertTrue(update.animated)
        XCTAssertEqual(update.sections[0].items.count, 3)

        let expandedRoot = try rootViewModel(from: update.sections)
        XCTAssertTrue(expandedRoot.isExpanded)
    }
}

private extension TokensManagePresenterTests {
    struct Context {
        let presenter: TokensManagePresenter
        let view: ViewRecorder
    }

    final class ViewRecorder: TokensManageViewProtocol {
        struct Update {
            let sections: [TokensManageSection]
            let animated: Bool
        }

        var updates: [Update] = []
        let controller = UIViewController()
        var isSetup: Bool {
            true
        }

        func didReceive(sections: [TokensManageSection], animated: Bool) {
            updates.append(Update(sections: sections, animated: animated))
        }

        func didReceive(autoAddTokens _: Bool) {}
    }

    final class InteractorStub: TokensManageInteractorInputProtocol {
        func setup() {}
        func save(chainAssetIds _: Set<ChainAssetId>, isVisible _: Bool) {}
        func save(autoAddTokensWithBalance _: Bool) {}
    }

    final class WireframeStub: TokensManageWireframeProtocol {
        func showAddToken(from _: TokensManageViewProtocol?) {}
    }

    func makeContext() -> Context {
        let factory = TokensManageViewModelFactory(
            quantityFormater: NumberFormatter.quantity.localizableResource(),
            assetIconViewModelFactory: AssetIconViewModelFactory(),
            networkViewModelFactory: NetworkViewModelFactory()
        )
        let presenter = TokensManagePresenter(
            interactor: InteractorStub(),
            wireframe: WireframeStub(),
            viewModelFactory: factory,
            localizationManager: LocalizationManager.shared
        )
        let view = ViewRecorder()
        presenter.view = view

        return Context(presenter: presenter, view: view)
    }

    func prepare(context: Context, chains: [ChainModel], defaults: [ChainAssetId]) {
        context.presenter.didReceiveGroupStyle(.networks)
        context.presenter.didReceiveVisibility(changes: [])
        context.presenter.didReceiveDefaultAssets(DefaultAssetsList(ids: defaults))
        context.presenter.didReceiveChainModel(changes: chains.map { .insert(newItem: $0) })
    }

    func rootGroupIds(in section: TokensManageSection) -> [String] {
        section.items.compactMap { item in
            guard case let .root(root) = item else { return nil }
            return root.groupId
        }
    }

    func rootViewModel(from sections: [TokensManageSection]) throws -> TokensManageRootViewModel {
        let item = try XCTUnwrap(sections.first?.items.first)

        guard case let .root(root) = item else {
            throw CommonError.undefined
        }

        return root
    }
}
