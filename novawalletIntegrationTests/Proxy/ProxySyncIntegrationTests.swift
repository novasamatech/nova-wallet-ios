import XCTest
@testable import novawallet
import RobinHood

class ProxySyncIntegrationTests: XCTestCase {
    func testSync() {
        let chainId = KnowChainId.kusama
        let storageFacade = SubstrateStorageTestFacade()
        let userStorageFacade = UserDataStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        
        let connection = chainRegistry.getConnection(for: chainId)!
        let runtimeService = chainRegistry.getRuntimeProvider(for: chainId)!
        
        let substrateAccountId = try? "1ChFWeNRLarAPRCTM3bfJmncJbSAbSS9yqjueWz7jX7iTVZ".toAccountId()
        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        
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
        
        
        let syncService = ProxySyncService(
            chainRegistry: chainRegistry,
            userDataStorageFacade: userStorageFacade,
            proxyOperationFactory: ProxyOperationFactory()
        )
        
        let completionExpectation = XCTestExpectation()

        syncService.setup()

        syncService.subscribeSyncState(
            self,
            queue: nil
        ) { (_, state) in
            let allSynced = state.values.allSatisfy({ !$0 })
             
            Logger.shared.info("State change: \(state)")
            
            if allSynced {
                completionExpectation.fulfill()
            }
        }
        
        wait(for: [completionExpectation], timeout: 6000)
    }
}
