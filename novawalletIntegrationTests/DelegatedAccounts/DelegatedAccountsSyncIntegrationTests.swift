import XCTest
@testable import novawallet
import Operation_iOS

final class DelegatedAccountsSyncIntegrationTests: XCTestCase {
    func testKusamaSync() throws {
        let kusamaAccountId = try "G4qFCkKu7BiaWFNLXfcdZpY94hndyKnzqY1JtmiSBsTPSxC".toAccountId()

        testSyncChain(
            chainId: KnowChainId.kusama,
            substrateAccountId: kusamaAccountId,
            checkAccountClosure: checkProxyAdded
        )
    }

    func testPolkadotSync() throws {
        let polkadotAccountId = try "16aBtmicQscoxSYDZGNzVJFTHS1GoeDWx51whmKxLFSZCYTU".toAccountId()

        testSyncChain(
            chainId: KnowChainId.polkadot,
            substrateAccountId: polkadotAccountId,
            checkAccountClosure: checkProxyAdded
        )
    }

    func testMultisigSync() throws {
        let polkadotAccountId = try "1ChFWeNRLarAPRCTM3bfJmncJbSAbSS9yqjueWz7jX7iTVZ".toAccountId()

        testSyncChain(
            chainId: KnowChainId.polkadot,
            substrateAccountId: polkadotAccountId,
            checkAccountClosure: checkMultisigAdded
        )
    }

    func checkProxyAdded(to metaAccounts: [ManagedMetaAccountModel]) -> Bool {
        metaAccounts.first(where: { $0.info.type == .proxied }) != nil
    }

    func checkMultisigAdded(to metaAccounts: [ManagedMetaAccountModel]) -> Bool {
        metaAccounts.first { metaAccount in
            metaAccount.info.chainAccounts.contains { $0.multisig != nil }
        } != nil
    }

    func testSyncChain(
        chainId: ChainModel.Id,
        substrateAccountId: AccountId,
        checkAccountClosure: @escaping ([ManagedMetaAccountModel]) -> Bool
    ) {
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

        let walletStorageCleaner = WalletStorageCleanerFactory.createWalletStorageCleaner(
            using: operationQueue
        )

        let walletUpdateMediator = WalletUpdateMediator(
            selectedWalletSettings: SelectedWalletSettings(storageFacade: userStorageFacade, operationQueue: operationQueue),
            repository: managedAccountRepository,
            walletsCleaner: walletStorageCleaner,
            operationQueue: operationQueue
        )

        let syncService = DelegatedAccountSyncService(
            chainRegistry: chainRegistry,
            metaAccountsRepository: managedAccountRepository,
            walletUpdateMediator: walletUpdateMediator,
            chainFilter: .chainId(chainId),
            chainWalletFilter: { _ in true }
        )

        let completionExpectation = XCTestExpectation()

        syncService.setup()

        syncService.subscribeSyncState(
            self,
            queue: nil
        ) { _, state in
            let synced = state

            if synced {
                do {
                    let fetchWalletsOperation = managedAccountRepository.fetchAllOperation(with: RepositoryFetchOptions())
                    operationQueue.addOperations([fetchWalletsOperation], waitUntilFinished: true)
                    let wallets = try fetchWalletsOperation.extractNoCancellableResultData()
                    if checkAccountClosure(wallets) {
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
            type: .watchOnly,
            multisig: nil
        )

        return ManagedMetaAccountModel(
            info: wallet,
            isSelected: true,
            order: 1
        )
    }
}
