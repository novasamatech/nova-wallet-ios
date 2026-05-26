import XCTest
@testable import novawallet

final class BrowserNavigationPresenterTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Seed the singleton so the routing path believes staking.polkadot.cloud is blocked.
        // The provider exposes a test seam (see StakingCompetitorsRemoteProvider).
        StakingCompetitorsRemoteProvider.shared.injectDomainsForTesting(["staking.polkadot.cloud"])
    }

    override func tearDown() {
        StakingCompetitorsRemoteProvider.shared.injectDomainsForTesting([])
        super.tearDown()
    }

    // MARK: - Test doubles

    final class MainAppContainerSpy: NovaMainAppContainerViewProtocol {
        var isSetup: Bool { true }
        var controller: UIViewController { UIViewController() }
        var browserNavigation: BrowserNavigationProtocol? { nil }
        var openedTabs: [DAppBrowserTab?] = []
        var closeAndShowStakingCallCount = 0

        func openBrowser(with tab: DAppBrowserTab?) {
            openedTabs.append(tab)
        }

        func closeBrowserAndShowStaking() {
            closeAndShowStakingCallCount += 1
        }
    }

    final class InteractorStub: BrowserNavigationInteractorInputProtocol {
        func setup() {}
    }

    // MARK: - Helpers

    private func makeTab(url: String) -> DAppBrowserTab {
        DAppBrowserTab(
            uuid: UUID(),
            name: "Test Tab",
            url: URL(string: url)!,
            metaId: "test-meta-id",
            createdAt: Date(),
            renderModifiedAt: nil,
            transportStates: nil,
            desktopOnly: nil,
            icon: nil
        )
    }

    private func makeSUT(container: NovaMainAppContainerViewProtocol) -> BrowserNavigationPresenter {
        let factory = BrowserNavigationTaskFactory()
        let presenter = BrowserNavigationPresenter(
            interactor: InteractorStub(),
            browserNavigationTaskFactory: factory
        )
        presenter.mainAppContainer = container
        return presenter
    }

    // MARK: - Tests

    func test_continue_replaysOriginalTabPreservingIdentity() {
        let container = MainAppContainerSpy()
        let presenter = makeSUT(container: container)
        let originalTab = makeTab(url: "https://staking.polkadot.cloud/dashboard")

        // Simulate the routing decision that sets pendingTab
        presenter.routeOrWarnForTesting(tab: originalTab)
        XCTAssertEqual(container.openedTabs.count, 0, "Blocked URL should not open browser immediately")

        // User taps Continue
        presenter.dappStakingWarningDidSelectContinue(to: originalTab.url)

        XCTAssertEqual(container.openedTabs.count, 1)
        let replayedTab = container.openedTabs.first!
        XCTAssertEqual(replayedTab?.uuid, originalTab.uuid, "Continue must preserve the original tab UUID")
        XCTAssertEqual(replayedTab?.name, originalTab.name, "Continue must preserve the original tab name")
        XCTAssertEqual(replayedTab?.metaId, originalTab.metaId, "Continue must preserve the original metaId")
    }

    func test_routing_reentryGuard_dropsSecondRequestWhileWarningOnScreen() {
        let container = MainAppContainerSpy()
        let presenter = makeSUT(container: container)
        let firstTab = makeTab(url: "https://staking.polkadot.cloud/")
        let secondTab = makeTab(url: "https://staking.polkadot.cloud/validators")

        presenter.routeOrWarnForTesting(tab: firstTab)
        presenter.routeOrWarnForTesting(tab: secondTab) // should be dropped — pendingTab != nil

        presenter.dappStakingWarningDidSelectContinue(to: firstTab.url)

        XCTAssertEqual(container.openedTabs.count, 1, "Only the first warning's Continue should fire")
        XCTAssertEqual(container.openedTabs.first??.uuid, firstTab.uuid, "Must replay the first tab, not the dropped second")
    }

    func test_goToStake_callsContainerCloseAndShowStaking() {
        let container = MainAppContainerSpy()
        let presenter = makeSUT(container: container)
        let tab = makeTab(url: "https://staking.polkadot.cloud/")

        presenter.routeOrWarnForTesting(tab: tab)
        presenter.dappStakingWarningDidSelectGoToStake()

        XCTAssertEqual(container.closeAndShowStakingCallCount, 1)
        XCTAssertEqual(container.openedTabs.count, 0, "Go-to-Stake should not open the browser")
    }

    func test_nonBlockedURL_opensBrowserDirectlyWithoutWarning() {
        let container = MainAppContainerSpy()
        let presenter = makeSUT(container: container)
        let tab = makeTab(url: "https://app.hydration.net/NOVA") // not in competitor list

        presenter.routeOrWarnForTesting(tab: tab)

        XCTAssertEqual(container.openedTabs.count, 1)
        XCTAssertEqual(container.openedTabs.first??.uuid, tab.uuid)
    }
}
