import XCTest
@testable import novawallet
import RobinHood

final class WalletUpdateMediatorTests: XCTestCase {
    struct Common {
        let operationQueue: OperationQueue
        let selectedAccountSettings: SelectedWalletSettings
        let repository: AnyDataProviderRepository<ManagedMetaAccountModel>
        let walletUpdateMediator: WalletUpdateMediating

        init() {
            operationQueue = OperationQueue()
            let facade = UserDataStorageTestFacade()

            selectedAccountSettings = SelectedWalletSettings(
                storageFacade: facade,
                operationQueue: operationQueue
            )

            let mapper = ManagedMetaAccountMapper()
            let coreDataRepository = facade.createRepository(mapper: AnyCoreDataMapper(mapper))
            repository = AnyDataProviderRepository(coreDataRepository)
            walletUpdateMediator = WalletUpdateMediator(
                selectedWalletSettings: selectedAccountSettings,
                repository: repository,
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
        
        init() {
            proxyWallet1 = ManagedMetaAccountModel(
                info: AccountGenerator.generateMetaAccount(generatingChainAccounts: 0),
                isSelected: false,
                order: 0
            )
            
            proxyWallet2 = ManagedMetaAccountModel(
                info: AccountGenerator.generateMetaAccount(generatingChainAccounts: 0),
                isSelected: false,
                order: 1
            )
            
            let proxied1ChainAccount = AccountGenerator.generateProxiedChainAccount(for: .init(
                type: .any,
                accountId: proxyWallet1.info.substrateAccountId!,
                status: .active
            ))
            
            proxiedForWallet1 = ManagedMetaAccountModel(
                info: AccountGenerator.generateMetaAccount(with: [proxied1ChainAccount], type: .proxied),
                isSelected: true,
                order: 2
            )
            
            let proxied2ChainAccount = AccountGenerator.generateProxiedChainAccount(for: .init(
                type: .staking,
                accountId: proxyWallet2.info.substrateAccountId!,
                status: .active
            ))
            
            proxiedForWallet2 = ManagedMetaAccountModel(
                info: AccountGenerator.generateMetaAccount(with: [proxied2ChainAccount], type: .proxied),
                isSelected: false,
                order: 3
            )
            
            // include nested proxied for wallet1
            
            let proxied3ChainAccount = AccountGenerator.generateProxiedChainAccount(for: .init(
                type: .any,
                accountId: proxied1ChainAccount.accountId,
                status: .active
            ))
            
            proxiedForProxiedWallet1 = ManagedMetaAccountModel(
                info: AccountGenerator.generateMetaAccount(with: [proxied3ChainAccount], type: .proxied),
                isSelected: false,
                order: 4
            )
        }
        
        var allWallets: [ManagedMetaAccountModel] {
            [proxyWallet1, proxyWallet2, proxiedForWallet1, proxiedForWallet2, proxiedForProxiedWallet1]
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
        
        // when
        
        let wrapper = common.walletUpdateMediator.saveChanges {
            .init(newOrUpdatedItems: [], removedItems: [removedWallet])
        }
        
        common.operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)
        
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
        let proxyWallets = ProxyWallets()
        
        common.setup(with: proxyWallets.allWallets)
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
    
    func testAutoSwitchWalletIfProxiedRevoked() throws {
        // given
        
        let common = Common()
        let proxyWallets = ProxyWallets()
        
        common.setup(with: proxyWallets.allWallets)
        
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
}
