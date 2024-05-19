import XCTest
@testable import novawallet
import RobinHood
import SoraKeystore

final class CloudBackupSyncTests: XCTestCase {
    typealias LocalWalletsSetupClosure = (SelectedWalletSettings, KeystoreProtocol) -> Void
    
    typealias LocalWalletsChangeClosure = (
        SelectedWalletSettings,
        KeystoreProtocol,
        CloudBackupSyncMetadataManaging
    ) -> Void
    
    typealias BackupSetupClosure = (
        CloudBackupServiceFactoryProtocol,
        CloudBackupSyncMetadataManaging,
        KeystoreProtocol
    ) -> Void
    
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
            configuringLocal: { walletSettings, keystore in
                try? (0..<10).forEach { _ in
                    try AccountCreationHelper.createMetaAccountFromMnemonic(
                        cryptoType: .sr25519,
                        keychain: keystore,
                        settings: walletSettings
                    )
                }
            },
            configuringBackup: { _, metadataManager, _ in
                metadataManager.isBackupEnabled = true
                try? metadataManager.savePassword("Test7777")
                metadataManager.saveLastSyncDate(nil)
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
        XCTAssertTrue(setupResult.syncMetadataManager.hasLastSyncDate())
        XCTAssertTrue(try setupResult.syncMetadataManager.hasPassword())
    }
    
    func testDetectLocalChanges() {
        let logger = Logger.shared
        
        var backupTime: UInt64?
        
        let setupResult = syncUpInitial(
            configuringLocal: { walletSettings, keystore in
                try? (0..<10).forEach { _ in
                    try AccountCreationHelper.createMetaAccountFromMnemonic(
                        cryptoType: .sr25519,
                        keychain: keystore,
                        settings: walletSettings
                    )
                }
            },
            changingAfterBackup: { walletSettings, keystore, syncMetadataManager  in
                backupTime = syncMetadataManager.getLastSyncDate()
                syncMetadataManager.saveLastSyncDate(0)
                
                walletSettings.remove(value: walletSettings.value)
                
                try? (0..<10).forEach { _ in
                    try AccountCreationHelper.createMetaAccountFromMnemonic(
                        cryptoType: .sr25519,
                        keychain: keystore,
                        settings: walletSettings
                    )
                }
            }
        )
        
        let syncChanges: CloudBackupSyncResult.Changes? = syncAndWait(service: setupResult.syncService) { result in
            logger.debug("Result: \(result)")
            switch result {
            case let .changes(changes):
                guard case .updateLocal = changes else {
                    return nil
                }
                
                return changes
            default:
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
        XCTAssertTrue(setupResult.syncMetadataManager.getLastSyncDate()! >= backupTime!)
        XCTAssertEqual(try setupResult.syncMetadataManager.getPassword(), Self.defaultPassword)
    }
    
    func testDetectRemoteChanges() {
        let logger = Logger.shared
        
        let setupResult = syncUpInitial(
            configuringLocal: { walletSettings, keystore in
                try? (0..<10).forEach { _ in
                    try AccountCreationHelper.createMetaAccountFromMnemonic(
                        cryptoType: .sr25519,
                        keychain: keystore,
                        settings: walletSettings
                    )
                }
            },
            changingAfterBackup: { walletSettings, keystore, syncMetadataManager  in
                let updateSyncTime = syncMetadataManager.getLastSyncDate()! + 1
                syncMetadataManager.saveLastSyncDate(updateSyncTime)
                
                walletSettings.remove(value: walletSettings.value)
                
                try? (0..<10).forEach { _ in
                    try AccountCreationHelper.createMetaAccountFromMnemonic(
                        cryptoType: .sr25519,
                        keychain: keystore,
                        settings: walletSettings
                    )
                }
            }
        )
        
        let syncChanges: CloudBackupSyncResult.Changes? = syncAndWait(service: setupResult.syncService) { result in
            logger.debug("Result: \(result)")
            switch result {
            case let .changes(changes):
                guard case .updateRemote = changes else {
                    return nil
                }
                
                return changes
            default:
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
        XCTAssertEqual(try setupResult.syncMetadataManager.getPassword(), Self.defaultPassword)
    }
    
    func testDetectUnion() {
        let logger = Logger.shared
        
        let setupResult = syncUpInitial(
            configuringLocal: { walletSettings, keystore in
                try? (0..<10).forEach { _ in
                    try AccountCreationHelper.createMetaAccountFromMnemonic(
                        cryptoType: .sr25519,
                        keychain: keystore,
                        settings: walletSettings
                    )
                }
            },
            changingAfterBackup: { walletSettings, keystore, syncMetadataManager  in
                syncMetadataManager.saveLastSyncDate(nil)
                
                walletSettings.remove(value: walletSettings.value)
                
                try? (0..<10).forEach { _ in
                    try AccountCreationHelper.createMetaAccountFromMnemonic(
                        cryptoType: .sr25519,
                        keychain: keystore,
                        settings: walletSettings
                    )
                }
            }
        )
        
        let syncChanges: CloudBackupSyncResult.Changes? = syncAndWait(service: setupResult.syncService) { result in
            logger.debug("Result: \(result)")
            switch result {
            case let .changes(changes):
                guard case .updateByUnion = changes else {
                    return nil
                }
                
                return changes
            default:
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
        XCTAssertEqual(try setupResult.syncMetadataManager.getPassword(), Self.defaultPassword)
    }
    
    private func syncUpInitial(
        configuringLocal: LocalWalletsSetupClosure,
        changingAfterBackup: LocalWalletsChangeClosure
    ) -> SyncSetupResult {
        let setupResult = setupSyncSevice(
            configuringLocal: configuringLocal,
            configuringBackup: { _, metadataManager, _ in
                metadataManager.isBackupEnabled = true
                try? metadataManager.savePassword(Self.defaultPassword)
                metadataManager.saveLastSyncDate(nil)
            }
        )
        
        let syncChanges: CloudBackupSyncResult.Changes? = syncAndWait(service: setupResult.syncService) { result in
            switch result {
            case let .changes(changes):
                return changes
            default:
                return nil
            }
        }
        
        guard let changes = syncChanges else {
            XCTFail("No changes found")
            return setupResult
        }
        
        applyChangesAndConfirm(
            changes,
            applicationFactory: setupResult.applicationFactory,
            syncService: setupResult.syncService
        )
        
        changingAfterBackup(
            setupResult.selectedWalletSettings,
            setupResult.keystore,
            setupResult.syncMetadataManager
        )
        
        return setupResult
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
        
        configuringLocal(walletSettingsManager, keystore)
        configuringBackup(serviceFactory, syncMetadataManager, keystore)
        
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
