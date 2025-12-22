import XCTest
@testable import novawallet
import Operation_iOS
import Cuckoo

final class BrowserStateCleaningTests: XCTestCase {
    @MainActor func testRemovedWalletBrowserStateCleanerRemovesTabsAndWebViews() throws {
        // given
        let context = TestContext.create()
        let removedWallet = createTestWallet()
        let tabIds: Set<UUID> = [UUID(), UUID()]

        stubTabManagerForRemoval(context.browserTabManager, returning: tabIds)

        let removedTabsCollector = stubWebViewEraser(context.webViewPoolEraser)

        let cleaner = RemovedWalletBrowserStateCleaner(
            browserTabManager: context.browserTabManager,
            webViewPoolEraser: context.webViewPoolEraser,
            operationQueue: context.operationQueue
        )

        let providers = createProviders(
            changes: [.delete(deletedIdentifier: removedWallet.identifier)],
            walletsBeforeChanges: [removedWallet.identifier: removedWallet]
        )

        // when
        let wrapper = cleaner.cleanStorage(using: providers)
        try executeAndWait(wrapper: wrapper, in: context.operationQueue)

        // then
        verify(context.browserTabManager, times(1))
            .removeAllWrapper(for: equal(to: Set([removedWallet.info.metaId])))
        XCTAssertEqual(removedTabsCollector.tabIds, tabIds)
    }

    @MainActor func testUpdatedWalletBrowserStateCleanerCleansForUpdatedChainAccounts() throws {
        // given
        let context = TestContext.create()
        let originalWallet = createTestWallet(isSelected: true, chainAccounts: 1)

        let updatedInfo = originalWallet.info.replacingChainAccount(
            AccountGenerator.generateChainAccount()
        )
        let updatedWallet = originalWallet.replacingInfo(updatedInfo)

        let tabs = [createTestTab(for: originalWallet)]
        let tabIds = Set(tabs.map(\.uuid))

        stubTabManagerForUpdate(context.browserTabManager, returning: tabs)

        let removedTabsCollector = stubWebViewEraser(context.webViewPoolEraser)

        let cleaner = UpdatedWalletBrowserStateCleaner(
            browserTabManager: context.browserTabManager,
            webViewPoolEraser: context.webViewPoolEraser,
            operationQueue: context.operationQueue
        )

        let providers = createProviders(
            changes: [.update(newItem: updatedWallet)],
            walletsBeforeChanges: [originalWallet.identifier: originalWallet]
        )

        // when
        let wrapper = cleaner.cleanStorage(using: providers)
        try executeAndWait(wrapper: wrapper, in: context.operationQueue)

        // then
        verify(context.browserTabManager, times(1)).cleanTransport(for: equal(to: tabIds))
        XCTAssertEqual(removedTabsCollector.tabIds, tabIds)
    }

    @MainActor func testUpdatedWalletBrowserStateCleanerSkipsWhenChainAccountsUnchanged() throws {
        // given
        let context = TestContext.create()
        let originalWallet = createTestWallet(isSelected: true, chainAccounts: 1)

        let updatedInfo = originalWallet.info.replacingName(with: "New Name")
        let updatedWallet = originalWallet.replacingInfo(updatedInfo)

        let tabs = [createTestTab(for: originalWallet)]

        stub(context.browserTabManager) { stub in
            when(stub.getAllTabs(for: equal(to: Set([updatedWallet.info.metaId]))))
                .thenReturn(CompoundOperationWrapper.createWithResult(tabs))
            when(stub.getAllTabs(for: equal(to: Set([]))))
                .thenReturn(CompoundOperationWrapper.createWithResult([]))
            when(stub.cleanTransport(for: any())).thenReturn(ClosureOperation {})
        }

        stub(context.webViewPoolEraser) { stub in
            when(stub.removeWebView(for: any())).thenDoNothing()
        }

        let cleaner = UpdatedWalletBrowserStateCleaner(
            browserTabManager: context.browserTabManager,
            webViewPoolEraser: context.webViewPoolEraser,
            operationQueue: context.operationQueue
        )

        let providers = createProviders(
            changes: [.update(newItem: updatedWallet)],
            walletsBeforeChanges: [originalWallet.identifier: originalWallet]
        )

        // when
        let wrapper = cleaner.cleanStorage(using: providers)
        try executeAndWait(wrapper: wrapper, in: context.operationQueue)

        // then
        verify(context.webViewPoolEraser, never()).removeWebView(for: any())
        verify(context.browserTabManager, never()).cleanTransport(for: any())
    }
}

// MARK: - Private

private extension BrowserStateCleaningTests {
    struct TestContext {
        let operationQueue: OperationQueue
        let browserTabManager: MockDAppBrowserTabManagerProtocol
        let webViewPoolEraser: MockWebViewPoolEraserProtocol

        @MainActor static func create() -> TestContext {
            TestContext(
                operationQueue: OperationQueue(),
                browserTabManager: MockDAppBrowserTabManagerProtocol(),
                webViewPoolEraser: MockWebViewPoolEraserProtocol()
            )
        }
    }

    class RemovedTabIdsCollector {
        var tabIds: Set<UUID> = []
    }

    // MARK: - Helpers

    func createTestWallet(isSelected: Bool = false, order: UInt32 = 0, chainAccounts: Int = 0) -> ManagedMetaAccountModel {
        ManagedMetaAccountModel(
            info: AccountGenerator.generateMetaAccount(generatingChainAccounts: chainAccounts),
            isSelected: isSelected,
            order: order
        )
    }

    func createProviders(
        changes: [DataProviderChange<ManagedMetaAccountModel>],
        walletsBeforeChanges: [String: ManagedMetaAccountModel]
    ) -> WalletStorageCleaningProviders {
        WalletStorageCleaningProviders(
            changesProvider: { changes },
            walletsBeforeChangesProvider: { walletsBeforeChanges }
        )
    }

    func createTestTab(for wallet: ManagedMetaAccountModel) -> DAppBrowserTab {
        DAppBrowserTab(
            uuid: UUID(),
            name: "Google",
            url: URL(string: "https://google.com")!,
            metaId: wallet.info.metaId,
            createdAt: Date(),
            renderModifiedAt: nil,
            transportStates: nil,
            desktopOnly: false,
            icon: nil
        )
    }

    func executeAndWait(
        wrapper: CompoundOperationWrapper<Void>,
        in queue: OperationQueue,
        timeout: TimeInterval = 10.0
    ) throws {
        let expectation = XCTestExpectation()

        wrapper.targetOperation.completionBlock = {
            expectation.fulfill()
        }

        queue.addOperations(wrapper.allOperations, waitUntilFinished: false)
        wait(for: [expectation], timeout: timeout)

        XCTAssertNoThrow(try wrapper.targetOperation.extractNoCancellableResultData())
    }

    func stubTabManagerForRemoval(
        _ manager: MockDAppBrowserTabManagerProtocol,
        returning tabIds: Set<UUID>
    ) {
        stub(manager) { stub in
            when(stub.removeAllWrapper(for: any())).thenReturn(
                CompoundOperationWrapper.createWithResult(tabIds)
            )
        }
    }

    func stubTabManagerForUpdate(
        _ manager: MockDAppBrowserTabManagerProtocol,
        returning tabs: [DAppBrowserTab]
    ) {
        stub(manager) { stub in
            when(stub.getAllTabs(for: any())).thenReturn(
                CompoundOperationWrapper.createWithResult(tabs)
            )
            when(stub.cleanTransport(for: any())).thenReturn(
                ClosureOperation {}
            )
        }
    }

    func stubWebViewEraser(
        _ eraser: MockWebViewPoolEraserProtocol
    ) -> RemovedTabIdsCollector {
        let collector = RemovedTabIdsCollector()
        stub(eraser) { stub in
            when(stub.removeWebView(for: any())).then { tabId in
                collector.tabIds.insert(tabId)
            }
        }
        return collector
    }
}
