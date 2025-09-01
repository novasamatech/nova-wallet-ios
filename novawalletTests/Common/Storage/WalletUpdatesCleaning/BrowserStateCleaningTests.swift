import XCTest
@testable import novawallet
import Operation_iOS
import Cuckoo

final class BrowserStateCleaningTests: XCTestCase {
    @MainActor func testRemovedWalletBrowserStateCleanerRemovesTabsAndWebViews() throws {
        // given
        let operationQueue = OperationQueue()
        let browserTabManager = MockDAppBrowserTabManagerProtocol()
        let webViewPoolEraser = MockWebViewPoolEraserProtocol()
        
        let cleaner = RemovedWalletBrowserStateCleaner(
            browserTabManager: browserTabManager,
            webViewPoolEraser: webViewPoolEraser,
            operationQueue: operationQueue
        )
        
        let removedWallet = ManagedMetaAccountModel(
            info: AccountGenerator.generateMetaAccount(generatingChainAccounts: 0),
            isSelected: false,
            order: 0
        )
        
        let tabIds: Set<UUID> = [UUID(), UUID()]
        
        stub(browserTabManager) { stub in
            when(stub.removeAllWrapper(for: any())).thenReturn(
                CompoundOperationWrapper.createWithResult(tabIds)
            )
        }
        
        var removedTabIds: Set<UUID> = []
        stub(webViewPoolEraser) { stub in
            when(stub.removeWebView(for: any())).then { tabId in
                removedTabIds.insert(tabId)
            }
        }
        
        let providers = WalletStorageCleaningProviders(
            changesProvider: {
                [DataProviderChange.delete(deletedIdentifier: removedWallet.identifier)]
            },
            walletsBeforeChangesProvider: {
                [removedWallet.identifier: removedWallet]
            }
        )
        
        let expectation = XCTestExpectation()
        
        // when
        let wrapper = cleaner.cleanStorage(using: providers)
        
        wrapper.targetOperation.completionBlock = {
            expectation.fulfill()
        }
        
        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
        
        wait(for: [expectation], timeout: 10.0)
        
        // then
        XCTAssertNoThrow(try wrapper.targetOperation.extractNoCancellableResultData())
        verify(browserTabManager, times(1)).removeAllWrapper(for: equal(to: Set([removedWallet.info.metaId])))
        XCTAssertEqual(removedTabIds, tabIds)
    }
    
    @MainActor func testUpdatedWalletBrowserStateCleanerCleansForUpdatedChainAccounts() throws {
        // given
        let operationQueue = OperationQueue()
        let browserTabManager = MockDAppBrowserTabManagerProtocol()
        let webViewPoolEraser = MockWebViewPoolEraserProtocol()
        
        let cleaner = UpdatedWalletBrowserStateCleaner(
            browserTabManager: browserTabManager,
            webViewPoolEraser: webViewPoolEraser,
            operationQueue: operationQueue
        )
        
        let originalWallet = ManagedMetaAccountModel(
            info: AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
            isSelected: true,
            order: 0
        )
        
        // Update wallet with different chain accounts
        let updatedInfo = originalWallet.info.replacingChainAccount(
            AccountGenerator.generateChainAccount()
        )
        let updatedWallet = originalWallet.replacingInfo(updatedInfo)
        
        let tabs = [
            DAppBrowserTab(
                uuid: UUID(),
                name: "Google",
                url: URL(string: "https://google.com")!,
                metaId: originalWallet.info.metaId,
                createdAt: Date(),
                renderModifiedAt: nil,
                transportStates: nil,
                desktopOnly: false,
                icon: nil
            )
        ]
        let tabIds = Set(tabs.map(\.uuid))
        
        stub(browserTabManager) { stub in
            when(stub.getAllTabs(for: equal(to: Set([updatedWallet.info.metaId])))).thenReturn(
                CompoundOperationWrapper.createWithResult(tabs)
            )
            when(stub.cleanTransport(for: any())).thenReturn(
                ClosureOperation { }
            )
        }
        
        var removedTabIds: Set<UUID> = []
        stub(webViewPoolEraser) { stub in
            when(stub.removeWebView(for: any())).then { tabId in
                removedTabIds.insert(tabId)
            }
        }
        
        let providers = WalletStorageCleaningProviders(
            changesProvider: {
                [DataProviderChange.update(newItem: updatedWallet)]
            },
            walletsBeforeChangesProvider: {
                [originalWallet.identifier: originalWallet]
            }
        )
        
        let expectation = XCTestExpectation()
        
        // when
        let wrapper = cleaner.cleanStorage(using: providers)
        wrapper.targetOperation.completionBlock = {
            expectation.fulfill()
        }
        
        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
        
        wait(for: [expectation], timeout: 10.0)
        
        // then
        XCTAssertNoThrow(try wrapper.targetOperation.extractNoCancellableResultData())
        verify(browserTabManager, times(1)).cleanTransport(for: equal(to: tabIds))
        XCTAssertEqual(removedTabIds, tabIds)
    }
    
    @MainActor func testUpdatedWalletBrowserStateCleanerSkipsWhenChainAccountsUnchanged() throws {
        // given
        let operationQueue = OperationQueue()
        let browserTabManager = MockDAppBrowserTabManagerProtocol()
        let webViewPoolEraser = MockWebViewPoolEraserProtocol()
        
        let cleaner = UpdatedWalletBrowserStateCleaner(
            browserTabManager: browserTabManager,
            webViewPoolEraser: webViewPoolEraser,
            operationQueue: operationQueue
        )
        
        let originalWallet = ManagedMetaAccountModel(
            info: AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
            isSelected: true,
            order: 0
        )
        
        let updatedInfo = originalWallet.info.replacingName(with: "New Name")
        let updatedWallet = originalWallet.replacingInfo(updatedInfo)
        
        let tabs = [
            DAppBrowserTab(
                uuid: UUID(),
                name: "Google",
                url: URL(string: "https://google.com")!,
                metaId: originalWallet.info.metaId,
                createdAt: Date(),
                renderModifiedAt: nil,
                transportStates: nil,
                desktopOnly: false,
                icon: nil
            )
        ]
        
        stub(browserTabManager) { stub in
            when(stub.getAllTabs(for: equal(to: Set([updatedWallet.info.metaId])))).thenReturn(
                CompoundOperationWrapper.createWithResult(tabs)
            )
            when(stub.getAllTabs(for: equal(to: Set([])))).thenReturn(
                CompoundOperationWrapper.createWithResult([])
            )
            when(stub.cleanTransport(for: any())).thenReturn(
                ClosureOperation { }
            )
        }
        
        stub(webViewPoolEraser) { stub in
            when(stub.removeWebView(for: any())).thenDoNothing()
        }
        
        let providers = WalletStorageCleaningProviders(
            changesProvider: {
                [DataProviderChange.update(newItem: updatedWallet)]
            },
            walletsBeforeChangesProvider: {
                [originalWallet.identifier: originalWallet]
            }
        )
        
        let expectation = XCTestExpectation()
        
        // when
        let wrapper = cleaner.cleanStorage(using: providers)
        wrapper.targetOperation.completionBlock = {
            expectation.fulfill()
        }
        
        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
        
        wait(for: [expectation], timeout: 10.0)
        
        // then
        XCTAssertNoThrow(try wrapper.targetOperation.extractNoCancellableResultData())
        verify(webViewPoolEraser, never()).removeWebView(for: any())
        verify(browserTabManager, never()).cleanTransport(for: any())
    }
}
