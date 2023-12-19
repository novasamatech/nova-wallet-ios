import XCTest
@testable import novawallet
import RobinHood

final class ProxySyncIntegrationTests: XCTestCase {
    func testSync() throws {
        let kusamaAccountId = try "G4qFCkKu7BiaWFNLXfcdZpY94hndyKnzqY1JtmiSBsTPSxC".toAccountId()
        let polkadotAccountId = try "1W9ZuKSDehxWy7DUDYCirpTSytPAWfvhpzG5oFCha7h1Rnf".toAccountId()
        testSyncChain(chainId: KnowChainId.kusama, substrateAccountId: kusamaAccountId)
        testSyncChain(chainId: KnowChainId.polkadot, substrateAccountId: polkadotAccountId)
    }
    
    func testSyncChain(chainId: ChainModel.Id, substrateAccountId: AccountId) {
        let storageFacade = SubstrateStorageTestFacade()
        let userStorageFacade = UserDataStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let operationQueue = OperationQueue()
        
        let managedAccountRepository = AccountRepositoryFactory(storageFacade: userStorageFacade)
            .createManagedMetaAccountRepository(
                for: nil,
                sortDescriptors: [NSSortDescriptor.accountsByOrder]
            )
        let wallet = ManagedMetaAccountModel.watchOnlySample(for: substrateAccountId)
        
        let saveWalletOperation = managedAccountRepository
            .saveOperation({
                [wallet]
            }, { [] })
        
        operationQueue.addOperations([saveWalletOperation], waitUntilFinished: true)
        
        let syncService = ProxySyncService(
            chainRegistry: chainRegistry,
            userDataStorageFacade: userStorageFacade,
            proxyOperationFactory: ProxyOperationFactory(),
            metaAccountsRepository: managedAccountRepository,
            chainsFilter: { $0.chainId == chainId }
        )
        
        let completionExpectation = XCTestExpectation()
        
        syncService.setup()
        
        syncService.subscribeSyncState(
            self,
            queue: nil
        ) { (_, state) in
            let synced = state.values.allSatisfy({ !$0 }) && state.values.count == 1
            
            if synced {
                do {
                    let fetchWalletsOperation = managedAccountRepository.fetchAllOperation(with: RepositoryFetchOptions())
                    operationQueue.addOperations([fetchWalletsOperation], waitUntilFinished: true)
                    let wallets = try fetchWalletsOperation.extractNoCancellableResultData()
                    if let walletWithProxy = wallets.first(where: { $0.info.type == .proxied }) {
                        Logger.shared.info("Proxy wallet was added")
                        completionExpectation.fulfill()
                    } else {
                        XCTFail("No proxy in chain: \(chainId)")
                    }
                } catch {
                    XCTFail(error.localizedDescription)
                }
             
            }
        }
        
        wait(for: [completionExpectation], timeout: 6000)
    }

}

extension ManagedMetaAccountModel {
    static func watchOnlySample(for substrateAccountId: AccountId) -> ManagedMetaAccountModel {
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
        
        return ManagedMetaAccountModel(
            info: wallet,
            isSelected: true,
            order: 1
        )
    }
}
