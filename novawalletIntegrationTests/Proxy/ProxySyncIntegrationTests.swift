import XCTest
@testable import novawallet
import RobinHood

class ProxySyncIntegrationTests: XCTestCase {
    func testSync() throws {
        let storageFacade = SubstrateStorageTestFacade()
        let userStorageFacade = UserDataStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let substrateAccountId = try? "G4qFCkKu7BiaWFNLXfcdZpY94hndyKnzqY1JtmiSBsTPSxC".toAccountId()
        let operationQueue = OperationQueue()
        
        let managedAccountRepository = AccountRepositoryFactory(storageFacade: userStorageFacade)
            .createManagedMetaAccountRepository(
                for: nil,
                sortDescriptors: [NSSortDescriptor.accountsByOrder]
            )
        let wallet = MetaAccountModel(
            metaId: UUID().uuidString,
            name: "test",
            substrateAccountId: substrateAccountId,
            substrateCryptoType: 0,
            substratePublicKey: substrateAccountId,
            ethereumAddress: nil,
            ethereumPublicKey: nil,
            chainAccounts: [],
            type: .watchOnly
        )
        
        let accountItem = ManagedMetaAccountModel(
            info: wallet,
            isSelected: true,
            order: 1
        )

        let saveWalletOperation = managedAccountRepository
            .saveOperation({
                [accountItem]
            }, { [] })
        
        operationQueue.addOperations([saveWalletOperation], waitUntilFinished: true)
        
        let syncService = ProxySyncService(
            chainRegistry: chainRegistry,
            userDataStorageFacade: userStorageFacade,
            proxyOperationFactory: ProxyOperationFactory(),
            chainsFilter: { !$0.isTestnet }
        )
        
        let chainsStore = ChainsStore(chainRegistry: chainRegistry)
        let allProxyChains = chainsStore.availableChainIds().compactMap {
            let chain = chainsStore.getChain(for: $0)
            return chain?.hasProxy == true ? chain : nil
        }.filter { !$0.isTestnet }
        
        let completionExpectation = XCTestExpectation()

        syncService.setup()

        syncService.subscribeSyncState(
            self,
            queue: nil
        ) { (_, state) in
            let allSynced = state.values.allSatisfy({ !$0 })
             
            Logger.shared.info("State change: \(state)")
            
            if state.values.count == allProxyChains.count, allSynced {
                completionExpectation.fulfill()
            }
        }
        
        wait(for: [completionExpectation], timeout: 6000)
    }
}
