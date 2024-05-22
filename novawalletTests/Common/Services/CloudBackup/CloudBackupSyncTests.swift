import XCTest
@testable import novawallet
import RobinHood
import SoraKeystore

final class CloudBackupSyncTests: XCTestCase {
    struct LocalWalletsSetupParams {
        let walletSettings: SelectedWalletSettings
        let keystore: KeystoreProtocol
    }
    
    typealias LocalWalletsSetupClosure = (LocalWalletsSetupParams) -> Void
    
    struct LocalWalletsChangeParams {
        let walletSettings: SelectedWalletSettings
        let keystore: KeystoreProtocol
        let syncMetadataManager: CloudBackupSyncMetadataManaging
    }
    
    typealias LocalWalletsChangeClosure = (LocalWalletsChangeParams) -> Void
    
    struct BackupSetupParams {
        let serviceFactory: CloudBackupServiceFactoryProtocol
        let keystore: KeystoreProtocol
        let syncMetadataManager: CloudBackupSyncMetadataManaging
    }
    
    typealias BackupSetupClosure = (BackupSetupParams) -> Void
    
    struct ValidationParams {
        let localWalletsBeforeSync: Set<ManagedMetaAccountModel>
        let backupBeforeSync: CloudBackup.DecryptedFileModel?
        
        let changes: CloudBackupSyncResult.Changes
        
        let localWalletsAfterSync: Set<ManagedMetaAccountModel>
        let backupAfterSync: CloudBackup.DecryptedFileModel?
        
        let selectedWalletSettings: SelectedWalletSettings
        
        let keystore: KeystoreProtocol
        let syncMetadataManager: CloudBackupSyncMetadataManaging
    }
    
    typealias ValidateClosure = (ValidationParams) -> Void
    
    struct SyncSetupResult {
        let syncService: CloudBackupSyncServiceProtocol
        let applicationFactory: CloudBackupUpdateApplicationFactoryProtocol
        let syncMetadataManager: CloudBackupSyncMetadataManaging
        let serviceFactory: CloudBackupServiceFactoryProtocol
        let selectedWalletSettings: SelectedWalletSettings
        let accountRepository: AccountRepositoryFactoryProtocol
        let keystore: KeystoreProtocol
    }
    
    static let defaultPassword = "Test7777"
    
    func testDetectNoChangesAfterFirstBackup() throws {
        let logger = Logger.shared
        let setupResult = setupSyncSevice(
            configuringLocal: { params in
                try? (0..<10).forEach { _ in
                    try AccountCreationHelper.createMetaAccountFromMnemonic(
                        cryptoType: .sr25519,
                        keychain: params.keystore,
                        settings: params.walletSettings
                    )
                }
            },
            configuringBackup: { params in
                params.syncMetadataManager.isBackupEnabled = true
                try? params.syncMetadataManager.savePassword(Self.defaultPassword)
                params.syncMetadataManager.saveLastSyncTimestamp(nil)
            }
        )
        
        let syncChanges: CloudBackupSyncResult.Changes? = syncAndWait(service: setupResult.syncService) { result in
            switch result {
            case let .changes(changes):
                return changes
            default:
                logger.debug("Skipped: \(result)")
                return nil
            }
        }
        
        guard let changes = syncChanges else {
            XCTFail("No changes found")
            return
        }
        
        applyChangesAndConfirm(
            changes,
            applicationFactory: setupResult.applicationFactory,
            syncService: setupResult.syncService
        )
        
        XCTAssertTrue(setupResult.syncMetadataManager.isBackupEnabled)
        XCTAssertTrue(setupResult.syncMetadataManager.hasLastSyncTimestamp())
        XCTAssertTrue(try setupResult.syncMetadataManager.hasPassword())
    }
    
    func testDetectLocalChanges() throws {
        try performSyncTest(
            configuringLocal: { params in
                try? (0..<10).forEach { _ in
                    try AccountCreationHelper.createMetaAccountFromMnemonic(
                        cryptoType: .sr25519,
                        keychain: params.keystore,
                        settings: params.walletSettings
                    )
                }
            },
            changingAfterBackup: { params  in
                params.syncMetadataManager.saveLastSyncTimestamp(0)
                
                let wallet = params.walletSettings.value!
                params.walletSettings.remove(value: wallet)
                try? KeystoreValidationHelper.clearKeystore(for: wallet, keystore: params.keystore)
                
                try? AccountCreationHelper.createMetaAccountFromMnemonic(
                    cryptoType: .sr25519,
                    keychain: params.keystore,
                    settings: params.walletSettings
                )
            },
            validateClosure: { params in
                guard case let .updateLocal(updateLocal) = params.changes else {
                    XCTFail("Expected local update")
                    return
                }
                
                XCTAssertEqual(updateLocal.changes.count, 2)
                
                do {
                    let afterBackupWallets = Set(params.localWalletsAfterSync.map({ $0.info }))
                    
                    let properInsert = try updateLocal.changes.contains { change in
                        switch change {
                        case let .new(remote):
                            let hasSecrets = try KeystoreValidationHelper.validateMnemonicSecrets(
                                for: remote,
                                keystore: params.keystore
                            )
                            
                            return afterBackupWallets.contains(remote) && hasSecrets
                        default:
                            return false
                        }
                    }
                    
                    let properDelete = updateLocal.changes.contains { change in
                        switch change {
                        case let .delete(local):
                            return !afterBackupWallets.contains(local)
                        default:
                            return false
                        }
                    }
                    
                    XCTAssertTrue(properInsert && properDelete)
                    
                    XCTAssertEqual(updateLocal.syncTime, params.syncMetadataManager.getLastSyncTimestamp())
                    XCTAssertEqual(Self.defaultPassword, try params.syncMetadataManager.getPassword())
                    XCTAssertEqual(params.backupBeforeSync, params.backupAfterSync)
                } catch {
                    XCTFail("Error: \(error)")
                }
            }
        )
    }
    
    func testDetectRemoteChanges() throws {
        try performSyncTest(
            configuringLocal: { params in
                try? (0..<10).forEach { _ in
                    try AccountCreationHelper.createMetaAccountFromMnemonic(
                        cryptoType: .sr25519,
                        keychain: params.keystore,
                        settings: params.walletSettings
                    )
                }
            },
            changingAfterBackup: { params  in
                let updateSyncTime = params.syncMetadataManager.getLastSyncTimestamp()! + 1
                params.syncMetadataManager.saveLastSyncTimestamp(updateSyncTime)
                
                let wallet = params.walletSettings.value!
                params.walletSettings.remove(value: wallet)
                try? KeystoreValidationHelper.clearKeystore(for: wallet, keystore: params.keystore)
                
                try? AccountCreationHelper.createMetaAccountFromMnemonic(
                    cryptoType: .sr25519,
                    keychain: params.keystore,
                    settings: params.walletSettings
                )
            },
            validateClosure: { params in
                guard case let .updateRemote(updateRemote) = params.changes else {
                    XCTFail("Expected local update")
                    return
                }
                
                do {
                    let backupWalletsAfterSync = try CloudBackupFileModelConverter().convertFromPublicInfo(
                        models: params.backupAfterSync!.publicData.wallets
                    )
                    
                    XCTAssertEqual(backupWalletsAfterSync, Set(params.localWalletsAfterSync.map({ $0.info })))
                    XCTAssertEqual(updateRemote.syncTime, params.syncMetadataManager.getLastSyncTimestamp())
                    XCTAssertEqual(Self.defaultPassword, try params.syncMetadataManager.getPassword())
                } catch {
                    XCTFail("Error: \(error)")
                }
            }
        )
    }
    
    func testDetectUnion() throws {
        try performSyncTest(
            configuringLocal: { params in
                try? (0..<10).forEach { _ in
                    try AccountCreationHelper.createMetaAccountFromMnemonic(
                        cryptoType: .sr25519,
                        keychain: params.keystore,
                        settings: params.walletSettings
                    )
                }
            },
            changingAfterBackup: { params in
                params.syncMetadataManager.saveLastSyncTimestamp(nil)
                
                let wallet = params.walletSettings.value!
                params.walletSettings.remove(value: wallet)
                try? KeystoreValidationHelper.clearKeystore(for: wallet, keystore: params.keystore)
                
                try? AccountCreationHelper.createMetaAccountFromMnemonic(
                    cryptoType: .sr25519,
                    keychain: params.keystore,
                    settings: params.walletSettings
                )
            },
            validateClosure: { params in
                guard case let .updateByUnion(updateUnion) = params.changes else {
                    XCTFail("Expected local update")
                    return
                }
                
                XCTAssertEqual(updateUnion.addingWallets.count, 1)
                
                do {
                    let backupWalletsAfterSync = try CloudBackupFileModelConverter().convertFromPublicInfo(
                        models: params.backupAfterSync!.publicData.wallets
                    )
                    
                    XCTAssertEqual(backupWalletsAfterSync, Set(params.localWalletsAfterSync.map({ $0.info })))
                    XCTAssertEqual(updateUnion.syncTime, params.syncMetadataManager.getLastSyncTimestamp())
                    XCTAssertEqual(Self.defaultPassword, try params.syncMetadataManager.getPassword())
                } catch {
                    XCTFail("Error: \(error)")
                }
            }
        )
    }
    
    private func performSyncTest(
        configuringLocal: LocalWalletsSetupClosure,
        changingAfterBackup: LocalWalletsChangeClosure,
        validateClosure: ValidateClosure
    ) throws {
        let setupResult = setupSyncSevice(
            configuringLocal: configuringLocal,
            configuringBackup: { params in
                params.syncMetadataManager.isBackupEnabled = true
                try? params.syncMetadataManager.savePassword(Self.defaultPassword)
                params.syncMetadataManager.saveLastSyncTimestamp(nil)
            }
        )
        
        let initChanges: CloudBackupSyncResult.Changes? = syncAndWait(service: setupResult.syncService) { result in
            switch result {
            case let .changes(changes):
                return changes
            default:
                return nil
            }
        }
        
        guard let changes = initChanges else {
            XCTFail("No init changes found")
            return
        }
        
        applyChangesAndConfirm(
            changes,
            applicationFactory: setupResult.applicationFactory,
            syncService: setupResult.syncService
        )
        
        changingAfterBackup(
            .init(
                walletSettings: setupResult.selectedWalletSettings,
                keystore: setupResult.keystore,
                syncMetadataManager: setupResult.syncMetadataManager
            )
        )
        
        let walletsBeforeSync = try WalletsFetchHelper.fetchWallets(using: setupResult.accountRepository)
        let backupBeforeSync = try CloudBackupFetchHelper.fetchBackup(
            using: setupResult.serviceFactory,
            password: Self.defaultPassword
        )
        
        let optNextChanges: CloudBackupSyncResult.Changes? = syncAndWait(service: setupResult.syncService) { result in
            switch result {
            case let .changes(changes):
                return changes
            default:
                return nil
            }
        }
        
        guard let nextChanges = optNextChanges else {
            XCTFail("No next changes found")
            return
        }
        
        applyChangesAndConfirm(
            nextChanges,
            applicationFactory: setupResult.applicationFactory,
            syncService: setupResult.syncService
        )
        
        let walletsAfterSync = try WalletsFetchHelper.fetchWallets(using: setupResult.accountRepository)
        let backupAfterSync = try CloudBackupFetchHelper.fetchBackup(
            using: setupResult.serviceFactory,
            password: Self.defaultPassword
        )
        
        let validationParams = ValidationParams(
            localWalletsBeforeSync: walletsBeforeSync,
            backupBeforeSync: backupBeforeSync,
            changes: nextChanges,
            localWalletsAfterSync: walletsAfterSync,
            backupAfterSync: backupAfterSync,
            selectedWalletSettings: setupResult.selectedWalletSettings,
            keystore: setupResult.keystore,
            syncMetadataManager: setupResult.syncMetadataManager
        )
        
        validateClosure(validationParams)
    }
    
    private func applyChangesAndConfirm(
        _ changes: CloudBackupSyncResult.Changes,
        applicationFactory: CloudBackupUpdateApplicationFactoryProtocol,
        syncService: CloudBackupSyncServiceProtocol
    ) {
        let wrapper = applicationFactory.createUpdateApplyOperation(for: changes)
        
        let operationQueue = OperationQueue()
        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)
        
        _ = syncAndWait(service: syncService) { result in
            switch result {
            case .noUpdates:
                return ()
            default:
                return nil
            }
        }
    }
    
    private func setupSyncSevice(
        configuringLocal: LocalWalletsSetupClosure,
        configuringBackup: BackupSetupClosure
    ) -> SyncSetupResult {
        let fileManager = MockCloudBackupFileManager()
        let operationFactory = MockCloudBackupOperationFactory()
        let operationQueue = OperationQueue()
        
        let serviceFactory = MockCloudBackupServiceFactory(
            operationFactory: operationFactory,
            fileManager: fileManager
        )
        
        let storageFacade = UserDataStorageTestFacade()
        let walletSettingsManager = SelectedWalletSettings(
            storageFacade: storageFacade,
            operationQueue: operationQueue
        )
        
        let accountsRepositoryFactory = AccountRepositoryFactory(storageFacade: storageFacade)
        
        let keystore = InMemoryKeychain()
        
        let syncMetadataManager = MockCloudBackupSyncMetadataManager()
        
        let syncService = CloudBackupSyncFactory(
            serviceFactory: serviceFactory,
            syncMetadataManaging: syncMetadataManager,
            accountsRepositoryFactory: accountsRepositoryFactory,
            notificationCenter: NotificationCenter.default,
            operationQueue: operationQueue,
            logger: Logger.shared
        ).createSyncService(for: fileManager.getFileUrl()!)
        
        let walletsRepository = accountsRepositoryFactory.createManagedMetaAccountRepository(
            for: nil,
            sortDescriptors: []
        )
        
        let walletsUpdater = WalletUpdateMediator(
            selectedWalletSettings: walletSettingsManager,
            repository: walletsRepository,
            operationQueue: operationQueue
        )
        
        let applyFactory = CloudBackupUpdateApplicationFactory(
            serviceFactory: serviceFactory,
            walletRepositoryFactory: accountsRepositoryFactory,
            walletsUpdater: walletsUpdater,
            keystore: keystore,
            syncMetadataManager: syncMetadataManager,
            operationQueue: operationQueue
        )
        
        configuringLocal(
            .init(walletSettings: walletSettingsManager, keystore: keystore)
        )
        
        configuringBackup(
            .init(serviceFactory: serviceFactory, keystore: keystore, syncMetadataManager: syncMetadataManager)
        )
        
        return SyncSetupResult(
            syncService: syncService,
            applicationFactory: applyFactory,
            syncMetadataManager: syncMetadataManager,
            serviceFactory: serviceFactory,
            selectedWalletSettings: walletSettingsManager,
            accountRepository: accountsRepositoryFactory,
            keystore: keystore
        )
    }
    
    private func syncAndWait<T>(
        service: CloudBackupSyncServiceProtocol,
        closure: @escaping (CloudBackupSyncResult) -> T?,
        timeout: TimeInterval = 10
    ) -> T? {
        let expectation = XCTestExpectation()
        var resultValue: T?
        
        service.subscribeSyncResult(
            self,
            notifyingIn: .main
        ) { result in
            if let value = closure(result) {
                resultValue = value
                expectation.fulfill()
            }
        }
        
        if !service.getIsActive() {
            service.setup()
        } else {
            service.syncUp()
        }
        
        wait(for: [expectation], timeout: timeout)
        
        service.unsubscribeSyncResult(self)
        
        return resultValue
    }
}
