import XCTest
@testable import novawallet
import Operation_iOS
import Cuckoo

final class WalletUpdateMediatorTests: XCTestCase {
    struct Common {
        let operationQueue: OperationQueue
        let selectedAccountSettings: SelectedWalletSettings
        let repository: AnyDataProviderRepository<ManagedMetaAccountModel>
        let walletStorageCleaner: WalletStorageCleaning
        let walletUpdateMediator: WalletUpdateMediating

        init(storageCleaner: WalletStorageCleaning? = nil) {
            operationQueue = OperationQueue()
            let facade = UserDataStorageTestFacade()

            selectedAccountSettings = SelectedWalletSettings(
                storageFacade: facade,
                operationQueue: operationQueue
            )

            let mapper = ManagedMetaAccountMapper()
            let coreDataRepository = facade.createRepository(mapper: AnyCoreDataMapper(mapper))
            repository = AnyDataProviderRepository(coreDataRepository)
            walletStorageCleaner = if let storageCleaner {
                storageCleaner
            } else {
                WalletStorageCleanerFactory.createTestCleaner(
                    operationQueue: operationQueue,
                    storageFacade: facade
                )
            }
            walletUpdateMediator = WalletUpdateMediator(
                selectedWalletSettings: selectedAccountSettings,
                repository: repository,
                walletsCleaner: walletStorageCleaner,
                operationQueue: operationQueue
            )
        }
        
        func setup(with wallets: [ManagedMetaAccountModel]) {
            save(wallets: wallets)
        }
        
        func save(wallets: [ManagedMetaAccountModel]) {
            let saveOperation = repository.saveOperation({
                wallets
            }, { [] })
            
            operationQueue.addOperations([saveOperation], waitUntilFinished: true)
            selectedAccountSettings.setup()
        }
        
        func select(walletId: MetaAccountModel.Id) throws {
            let wallets = try allWallets().map { wallet in
                ManagedMetaAccountModel(
                    info: wallet.info,
                    isSelected: wallet.identifier == walletId,
                    order: wallet.order
                )
            }
            
            save(wallets: wallets)
        }
        
        func update(
            with newOrUpdate: [ManagedMetaAccountModel],
            remove: [ManagedMetaAccountModel]
        ) throws -> WalletUpdateMediatingResult {
            let wrapper = walletUpdateMediator.saveChanges {
                SyncChanges(newOrUpdatedItems: newOrUpdate, removedItems: remove)
            }
            
            operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)
            
            return try wrapper.targetOperation.extractNoCancellableResultData()
        }
        
        func allWallets() throws -> [ManagedMetaAccountModel] {
            let operation = repository.fetchAllOperation(with: .init())
            operationQueue.addOperations([operation], waitUntilFinished: true)
            
            return try operation.extractNoCancellableResultData()
        }
    }
    
    struct ProxyWallets {
        var proxyWallet1: ManagedMetaAccountModel
        
        var proxyWallet2: ManagedMetaAccountModel
        
        var proxiedForWallet1: ManagedMetaAccountModel
        
        var proxiedForWallet2: ManagedMetaAccountModel
        
        var proxiedForProxiedWallet1: ManagedMetaAccountModel
        
        var recursiveProxiedForProxiedWallet1: ManagedMetaAccountModel
        
        init(reversedOrder: Bool = false) {
            let allOrders: [UInt32] = (0...5).map({ $0 })
            let orders = reversedOrder ? allOrders.reversed() : allOrders
            
            let chainId = Data.random(of: 32)!.toHex()
            
            proxyWallet1 = ManagedMetaAccountModel(
                info: AccountGenerator.generateMetaAccount(generatingChainAccounts: 0),
                isSelected: false,
                order: orders[0]
            )
            
            proxyWallet2 = ManagedMetaAccountModel(
                info: AccountGenerator.generateMetaAccount(generatingChainAccounts: 0),
                isSelected: false,
                order: orders[1]
            )
            
            let proxied1ChainAccount = AccountGenerator.generateProxiedChainAccount(for: .init(
                type: .any,
                accountId: proxyWallet1.info.substrateAccountId!,
                status: .active
            ), chainId: chainId)
            
            proxiedForWallet1 = ManagedMetaAccountModel(
                info: AccountGenerator.generateMetaAccount(with: [proxied1ChainAccount], type: .proxied),
                isSelected: true,
                order: orders[2]
            )
            
            let proxied2ChainAccount = AccountGenerator.generateProxiedChainAccount(for: .init(
                type: .staking,
                accountId: proxyWallet2.info.substrateAccountId!,
                status: .active
            ), chainId: chainId)
            
            proxiedForWallet2 = ManagedMetaAccountModel(
                info: AccountGenerator.generateMetaAccount(with: [proxied2ChainAccount], type: .proxied),
                isSelected: false,
                order: orders[3]
            )
            
            // include nested proxied for wallet1
            
            let proxied3ChainAccount = AccountGenerator.generateProxiedChainAccount(for: .init(
                type: .any,
                accountId: proxied1ChainAccount.accountId,
                status: .active
            ), chainId: chainId)
            
            proxiedForProxiedWallet1 = ManagedMetaAccountModel(
                info: AccountGenerator.generateMetaAccount(with: [proxied3ChainAccount], type: .proxied),
                isSelected: false,
                order: orders[4]
            )
            
            // and cyclic proxied from proxied1 to proxied3
            
            let proxied4ChainAccount = ChainAccountModel(
                chainId: proxied1ChainAccount.chainId,
                accountId: proxied1ChainAccount.accountId,
                publicKey: proxied1ChainAccount.publicKey,
                cryptoType: 0,
                proxy: .init(
                    type: .any,
                    accountId: proxied3ChainAccount.accountId,
                    status: .active
                ),
                multisig: nil
            )
            
            recursiveProxiedForProxiedWallet1 = ManagedMetaAccountModel(
                info: AccountGenerator.generateMetaAccount(with: [proxied4ChainAccount], type: .proxied),
                isSelected: false,
                order: orders[5]
            )
        }
        
        var allWithoutRecursive: [ManagedMetaAccountModel] {
            [proxyWallet1, proxyWallet2, proxiedForWallet1, proxiedForWallet2, proxiedForProxiedWallet1]
        }
        
        var all: [ManagedMetaAccountModel] {
            [proxyWallet1, proxyWallet2, proxiedForWallet1, proxiedForWallet2, proxiedForProxiedWallet1, recursiveProxiedForProxiedWallet1]
        }
    }
    
    func testAutoSwitchWalletIfSelectedOneRemoved() {
        // given
        
        let common = Common()
        
        let wallets = (0..<20).map { index in
            ManagedMetaAccountModel(
                info: AccountGenerator.generateMetaAccount(generatingChainAccounts: 2),
                isSelected: index == 0,
                order: index
            )
        }
        
        common.setup(with: wallets)
        
        let removedWallet = wallets[0]
        
        XCTAssertTrue(common.selectedAccountSettings.value.identifier == removedWallet.identifier)
        
        do {
            // when
            
            let result = try common.update(with: [], remove: [removedWallet])
            
            // then
            
            XCTAssertTrue(result.isWalletSwitched)
            XCTAssertTrue(result.selectedWallet != nil)
            XCTAssertTrue(common.selectedAccountSettings.value.identifier != removedWallet.identifier)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testNoSwitchWalletIfNoSelectedAccountsRemoved() {
        // given
        
        let common = Common()
        
        let wallets = (0..<20).map { index in
            ManagedMetaAccountModel(
                info: AccountGenerator.generateMetaAccount(generatingChainAccounts: 2),
                isSelected: index == 0,
                order: index
            )
        }
        
        common.setup(with: wallets)
        
        let selectedWallet = wallets[0]
        let removedWallet = wallets[wallets.count - 1]
        
        XCTAssertTrue(common.selectedAccountSettings.value.identifier == selectedWallet.identifier)
        
        // then
        
        do {
            let result = try common.update(with: [], remove: [removedWallet])
            
            XCTAssertTrue(!result.isWalletSwitched)
            XCTAssertTrue(result.selectedWallet != nil)
            XCTAssertTrue(common.selectedAccountSettings.value.identifier == selectedWallet.identifier)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testRemoveNestedProxiedsWhenProxyRemovedAndAutoswitchSelectedWallet() throws {
        // given
        
        let common = Common()
        let proxyWallets = ProxyWallets(reversedOrder: true)
        
        common.setup(with: proxyWallets.allWithoutRecursive)
        try common.select(walletId: proxyWallets.proxiedForWallet1.identifier)
        
        XCTAssertEqual(common.selectedAccountSettings.value.identifier, proxyWallets.proxiedForWallet1.identifier)
        
        // then
        
        do {
            let result = try common.update(with: [], remove: [proxyWallets.proxyWallet1])
            
            let remainedWallets = try common.allWallets()
            let remainedIdentifiers = remainedWallets.map { $0.identifier }
            
            XCTAssertTrue(result.isWalletSwitched)
            XCTAssertEqual(result.selectedWallet?.identifier, common.selectedAccountSettings.value.identifier)
            XCTAssertEqual(common.selectedAccountSettings.value.identifier, proxyWallets.proxyWallet2.identifier)
            XCTAssertEqual(Set(remainedIdentifiers), [proxyWallets.proxyWallet2.identifier, proxyWallets.proxiedForWallet2.identifier])
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testRemoveRecursiveProxiedsWhenProxyRemoved() throws {
        // given
        
        let common = Common()
        let proxyWallets = ProxyWallets(reversedOrder: true)
        
        common.setup(with: proxyWallets.all)
        try common.select(walletId: proxyWallets.proxiedForWallet1.identifier)
        
        XCTAssertEqual(common.selectedAccountSettings.value.identifier, proxyWallets.proxiedForWallet1.identifier)
        
        // then
        
        do {
            let result = try common.update(with: [], remove: [proxyWallets.proxyWallet1])
            
            let remainedWallets = try common.allWallets()
            let remainedIdentifiers = remainedWallets.map { $0.identifier }
            
            XCTAssertTrue(result.isWalletSwitched)
            XCTAssertEqual(result.selectedWallet?.identifier, common.selectedAccountSettings.value.identifier)
            XCTAssertEqual(common.selectedAccountSettings.value.identifier, proxyWallets.proxyWallet2.identifier)
            XCTAssertEqual(Set(remainedIdentifiers), [proxyWallets.proxyWallet2.identifier, proxyWallets.proxiedForWallet2.identifier])
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testRecursiveWalletNotRemovedIfReachable() throws {
        // given
        
        let common = Common()
        let proxyWallets = ProxyWallets(reversedOrder: true)
        
        common.setup(with: proxyWallets.all)
        try common.select(walletId: proxyWallets.proxiedForWallet2.identifier)
        
        XCTAssertEqual(common.selectedAccountSettings.value.identifier, proxyWallets.proxiedForWallet2.identifier)
        
        // then
        
        do {
            let result = try common.update(with: [], remove: [proxyWallets.proxyWallet2])
            
            let remainedWallets = try common.allWallets()
            let remainedIdentifiers = remainedWallets.map { $0.identifier }
            
            XCTAssertTrue(result.isWalletSwitched)
            XCTAssertEqual(result.selectedWallet?.identifier, common.selectedAccountSettings.value.identifier)
            XCTAssertEqual(common.selectedAccountSettings.value.identifier, proxyWallets.proxyWallet1.identifier)
            XCTAssertEqual(
                Set(remainedIdentifiers),
                [
                    proxyWallets.proxyWallet1.identifier,
                    proxyWallets.proxiedForWallet1.identifier,
                    proxyWallets.proxiedForProxiedWallet1.identifier,
                    proxyWallets.recursiveProxiedForProxiedWallet1.identifier
                ]
            )
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testAutoSwitchWalletIfProxiedRevoked() throws {
        // given
        
        let common = Common()
        let proxyWallets = ProxyWallets()
        
        common.setup(with: proxyWallets.all)
        
        let proxied = proxyWallets.proxiedForWallet2
        try common.select(walletId: proxied.identifier)
        
        XCTAssertEqual(common.selectedAccountSettings.value.identifier, proxied.identifier)
        
        // when
        
        let newProxied = proxied.replacingInfo(
            proxied.info.replacingChainAccount(
                proxied.info.chainAccounts.first!.replacingProxyStatus(from: .active, to: .revoked)
            )
        )
        
        // then
        
        do {
            let result = try common.update(with: [newProxied], remove: [])
            XCTAssertTrue(result.isWalletSwitched)
            
            let maybeSelected: Set<MetaAccountModel.Id> = [proxyWallets.proxyWallet1.identifier, proxyWallets.proxyWallet2.identifier]
            XCTAssertTrue(maybeSelected.contains(common.selectedAccountSettings.value.identifier))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testAutoSwitchNewWalletIfAllRemoved() throws {
        // given
        
        let common = Common()
        
        let allWallets = (0..<6).map { (index: UInt32) in
            let metaAccount = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
            
            return ManagedMetaAccountModel(info: metaAccount, isSelected: false, order: index)
        }
        
        let oldWallets = Array(allWallets[0..<3])
        let newWallets = Array(allWallets[3..<6])
        
        common.setup(with: oldWallets)
        try common.select(walletId: oldWallets[0].identifier)
        
        // when
        
        let result = try common.update(with: newWallets, remove: oldWallets)
        
        // then
        
        XCTAssertTrue(result.isWalletSwitched)
        
        if let selectedWallet = result.selectedWallet {
            XCTAssertTrue(selectedWallet.isSelected)
            XCTAssertTrue(newWallets.contains(where: { $0.identifier == selectedWallet.identifier }))
        } else {
            XCTFail("Selected wallet expected")
        }
    }
    
    // MARK: - RemovedWalletBrowserStateCleaner Tests
    
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
    
    // MARK: - RemovedWalletDAppSettingsCleaner Tests
    
    func testRemovedWalletDAppSettingsCleanerRemovesSettings() throws {
        // given
        let operationQueue = OperationQueue()
        let facade = UserDataStorageTestFacade()
        let mapper = DAppSettingsMapper()
        let repository = facade.createRepository(mapper: AnyCoreDataMapper(mapper))
        let authorizedDAppRepository = AnyDataProviderRepository(repository)
        
        let cleaner = RemovedWalletDAppSettingsCleaner(
            authorizedDAppRepository: authorizedDAppRepository
        )
        
        let removedWallet = ManagedMetaAccountModel(
            info: AccountGenerator.generateMetaAccount(generatingChainAccounts: 0),
            isSelected: false,
            order: 0
        )
        let keepWallet = ManagedMetaAccountModel(
            info: AccountGenerator.generateMetaAccount(generatingChainAccounts: 0),
            isSelected: true,
            order: 1
        )
        
        let removedSettings = DAppSettings(
            dAppId: "google.com",
            metaId: removedWallet.info.metaId,
            source: nil
        )
        let keepSettings = DAppSettings(
            dAppId: "novasama.io",
            metaId: keepWallet.info.metaId,
            source: nil
        )
        
        let saveOperation = authorizedDAppRepository.saveOperation(
            { [removedSettings, keepSettings] },
            { [] }
        )
        operationQueue.addOperations([saveOperation], waitUntilFinished: true)
        
        let providers = WalletStorageCleaningProviders(
            changesProvider: {
                [DataProviderChange.delete(deletedIdentifier: removedWallet.identifier)]
            },
            walletsBeforeChangesProvider: {
                [removedWallet.identifier: removedWallet, keepWallet.identifier: keepWallet]
            }
        )
        
        // when
        let wrapper = cleaner.cleanStorage(using: providers)
        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)
        
        // then
        XCTAssertNoThrow(try wrapper.targetOperation.extractNoCancellableResultData())
        
        // Verify settings were removed
        let fetchOperation = authorizedDAppRepository.fetchAllOperation(with: .init())
        operationQueue.addOperations([fetchOperation], waitUntilFinished: true)
        
        let remainingSettings = try fetchOperation.extractNoCancellableResultData()
        XCTAssertEqual(remainingSettings.count, 1)
        XCTAssertEqual(remainingSettings.first?.metaId, keepWallet.info.metaId)
    }
}
