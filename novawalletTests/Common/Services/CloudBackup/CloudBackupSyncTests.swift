import XCTest
@testable import novawallet
import Operation_iOS
import Keystore_iOS

final class CloudBackupSyncTests: XCTestCase {
    struct LocalWalletsSetupParams {
        let walletSettings: SelectedWalletSettings
        let keystore: MockKeychain
    }
    
    typealias LocalWalletsSetupClosure = (LocalWalletsSetupParams) -> Void
    
    struct LocalWalletsChangeParams {
        let walletSettings: SelectedWalletSettings
        let keystore: MockKeychain
        let accountRepositoryFactory: AccountRepositoryFactoryProtocol
        let syncMetadataManager: CloudBackupSyncMetadataManaging
    }
    
    typealias LocalWalletsChangeClosure = (LocalWalletsChangeParams) -> Void
    
    struct BackupSetupParams {
        let serviceFactory: CloudBackupServiceFactoryProtocol
        let keystore: MockKeychain
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
        
        let keystoreAfterSetup: MockKeychain
        let keystoreAfterSync: MockKeychain
        let syncMetadataManager: CloudBackupSyncMetadataManaging
    }
    
    typealias ValidateClosure = (ValidationParams) -> Void
    
    struct SyncSetupResult {
        let syncService: CloudBackupSyncServiceProtocol
        let syncMetadataManager: CloudBackupSyncMetadataManaging
        let serviceFactory: CloudBackupServiceFactoryProtocol
        let selectedWalletSettings: SelectedWalletSettings
        let accountRepositoryFactory: AccountRepositoryFactoryProtocol
        let keystore: MockKeychain
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
        
        XCTAssertNotNil(syncChanges)
        
        applyChangesAndConfirm(for: setupResult.syncService)
        
        XCTAssertTrue(setupResult.syncMetadataManager.isBackupEnabled)
        XCTAssertTrue(setupResult.syncMetadataManager.hasLastSyncTimestamp())
        XCTAssertTrue(try setupResult.syncMetadataManager.hasPassword())
    }
    
    func testPreventApplyChangesIfSecretWalletHasNoSecrets() throws {
        let optIssue = performDetectIssueTest { params in
            // create a wallet with secrets
            try? AccountCreationHelper.createMetaAccountFromMnemonic(
                cryptoType: .sr25519,
                keychain: params.keystore,
                settings: params.walletSettings
            )
            
            // and then remove secrets before syncing
            try? KeystoreValidationHelper.clearKeystore(
                for: params.walletSettings.value,
                keystore: params.keystore
            )
        }
        
        XCTAssertEqual(optIssue, .internalFailure)
    }
    
    func testPreventApplyChangesIfLegacyLedgerWalletHasNoDPath() throws {
        let optIssue = performDetectIssueTest { params in
            guard let ledgerApp = SupportedLedgerApp.substrate().first else {
                return
            }
            
            try? AccountCreationHelper.createSubstrateLedgerAccount(
                from: ledgerApp,
                keychain: params.keystore,
                settings: params.walletSettings
            )
            
            // and then remove secrets before syncing
            try? KeystoreValidationHelper.clearKeystore(
                for: params.walletSettings.value,
                keystore: params.keystore
            )
        }
        
        XCTAssertEqual(optIssue, .internalFailure)
    }
    
    func testPreventApplyChangesIfGenericLedgerWalletHasNoSubstrateDPath() throws {
        let optIssue = performDetectIssueTest { params in
            try? AccountCreationHelper.createGenericLedgerWallet(
                keychain: params.keystore,
                settings: params.walletSettings,
                includesEvm: false
            )
            
            guard let wallet = params.walletSettings.value else {
                XCTFail("Generic Ledger Wallet expected")
                return
            }
            
            // and then substrate deriv path
            try? params.keystore.deleteKeyIfExists(
                for: KeystoreTagV2.substrateDerivationTagForMetaId(
                    wallet.metaId
                )
            )
        }
        
        XCTAssertEqual(optIssue, .internalFailure)
    }
    
    func testPreventApplyChangesIfGenericLedgerWalletHasNoEvmDPath() throws {
        let optIssue = performDetectIssueTest { params in
            try? AccountCreationHelper.createGenericLedgerWallet(
                keychain: params.keystore,
                settings: params.walletSettings,
                includesEvm: true
            )
            
            guard let wallet = params.walletSettings.value else {
                XCTFail("Generic Ledger Wallet expected")
                return
            }
            
            // and then evm deriva path
            try? params.keystore.deleteKeyIfExists(
                for: KeystoreTagV2.ethereumDerivationTagForMetaId(
                    wallet.metaId
                )
            )
        }
        
        XCTAssertEqual(optIssue, .internalFailure)
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
                                keystore: params.keystoreAfterSync
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
    
    func testBackupLedgerWallet() throws {
        try performSyncTest(
            configuringLocal: { params in
                for ledgerApp in SupportedLedgerApp.substrate() {
                    try? AccountCreationHelper.createSubstrateLedgerAccount(
                        from: ledgerApp,
                        keychain: params.keystore,
                        settings: params.walletSettings
                    )
                }
            },
            changingAfterBackup: { params in
                params.syncMetadataManager.saveLastSyncTimestamp(0)
                
                let wallet = params.walletSettings.value!
                params.walletSettings.remove(value: wallet)
                try? KeystoreValidationHelper.clearKeystore(for: wallet, keystore: params.keystore)
                
            }, 
            validateClosure: { params in
                guard case let .updateLocal(updateLocal) = params.changes else {
                    XCTFail("Expected local update")
                    return
                }
                
                XCTAssertEqual(updateLocal.changes.count, 1)
                
                do {
                    let afterBackupWallets = Set(params.localWalletsAfterSync.map({ $0.info }))
                    
                    let properInsert = try updateLocal.changes.contains { change in
                        switch change {
                        case let .new(remote):
                            let hasDerivPath = try KeystoreValidationHelper.validateChainAccountsHaveDerivationPaths(
                                for: remote,
                                keystore: params.keystoreAfterSync
                            )
                            
                            return afterBackupWallets.contains(remote) && hasDerivPath
                        default:
                            return false
                        }
                    }
                    
                    XCTAssertTrue(properInsert)
                    
                    XCTAssertEqual(updateLocal.syncTime, params.syncMetadataManager.getLastSyncTimestamp())
                    XCTAssertEqual(Self.defaultPassword, try params.syncMetadataManager.getPassword())
                    XCTAssertEqual(params.backupBeforeSync, params.backupAfterSync)
                    XCTAssertEqual(params.keystoreAfterSetup.getRawStore(), params.keystoreAfterSync.getRawStore())
                } catch {
                    XCTFail("Error: \(error)")
                }
            }
        )
    }
    
    func testBackupSubstrateGenericLedgerWallet() throws {
        try performBackupGenericLedgerWallet(includesEvm: false)
    }
    
    func testBackupSubstrateAndEvmGenericLedgerWallet() throws {
        try performBackupGenericLedgerWallet(includesEvm: true)
    }
    
    func testBackSubstrateAndEvmAndSyncWithNoEvmGenericLedgerWallet() throws {
        try performSyncTest(
            configuringLocal: { params in
                try? AccountCreationHelper.createGenericLedgerWallet(
                    keychain: params.keystore,
                    settings: params.walletSettings,
                    includesEvm: true
                )
            },
            changingAfterBackup: { params in
                params.syncMetadataManager.saveLastSyncTimestamp(0)
                
                let wallet = params.walletSettings.value!
                
                let newWallet = wallet
                    .replacingEthereumAddress(nil)
                    .replacingEthereumPublicKey(nil)
                
                params.walletSettings.save(value: newWallet)
                try? KeystoreValidationHelper.clearKeystore(for: wallet, keystore: params.keystore)
                
            },
            validateClosure: { params in
                guard case let .updateLocal(updateLocal) = params.changes else {
                    XCTFail("Expected local update")
                    return
                }
                
                XCTAssertEqual(updateLocal.changes.count, 1)
                
                do {
                    let afterBackupWallets = Set(params.localWalletsAfterSync.map({ $0.info }))
                    
                    let properUpdate = try updateLocal.changes.contains { change in
                        switch change {
                        case let .updatedMainAccounts(_, remote):
                            let hasSubstrateDerivPath = try KeystoreValidationHelper.validateMainSubstrateDerivationPath(
                                for: remote,
                                keystore: params.keystoreAfterSync
                            )
                            
                            let hasEvmDerivPath = try KeystoreValidationHelper.validateMainEthereumDerivationPath(
                                for: remote,
                                keystore: params.keystoreAfterSync
                            )
                            
                            return afterBackupWallets.contains(remote) &&
                                hasSubstrateDerivPath &&
                                hasEvmDerivPath
                        default:
                            return false
                        }
                    }
                    
                    XCTAssertTrue(properUpdate)
                    
                    XCTAssertEqual(updateLocal.syncTime, params.syncMetadataManager.getLastSyncTimestamp())
                    XCTAssertEqual(Self.defaultPassword, try params.syncMetadataManager.getPassword())
                    XCTAssertEqual(params.backupBeforeSync, params.backupAfterSync)
                    XCTAssertEqual(params.keystoreAfterSetup.getRawStore(), params.keystoreAfterSync.getRawStore())
                } catch {
                    XCTFail("Error: \(error)")
                }
            }
        )
    }
    
    func testBackupSubstrateGenericLedgerAndThenAddEvm() throws {
        try performSyncTest(
            configuringLocal: { params in
                try? AccountCreationHelper.createGenericLedgerWallet(
                    keychain: params.keystore,
                    settings: params.walletSettings,
                    includesEvm: false
                )
            },
            changingAfterBackup: { params in
                let wallet = params.walletSettings.value!

                let repository = params.accountRepositoryFactory.createMetaAccountRepository(
                    for: nil,
                    sortDescriptors: []
                )
                
                try? AccountCreationHelper.addGenericLedgerEvmAccountsInWallet(
                    wallet: wallet,
                    keychain: params.keystore,
                    settings: params.walletSettings,
                    repository: repository
                )
                
            },
            validateClosure: { params in
                guard case let .updateRemote(updateRemote) = params.changes else {
                    XCTFail("Expected local update")
                    return
                }
                
                XCTAssertEqual(updateRemote.localWallets.count, 1)
                
                do {
                    let afterBackupWallets = Set(params.localWalletsAfterSync.map({ $0.info }))
                    
                    guard
                        let localWallet = afterBackupWallets.first,
                        let remoteWallet = updateRemote.localWallets.first?.info else {
                        XCTFail("Expected one wallet to update")
                        return
                    }
                    
                    XCTAssertEqual(localWallet, remoteWallet)
                    
                    let hasSubstrateDerivPath = try KeystoreValidationHelper.validateMainSubstrateDerivationPath(
                        for: remoteWallet,
                        keystore: params.keystoreAfterSync
                    )
                    
                    let hasEvmDerivPath = try KeystoreValidationHelper.validateMainEthereumDerivationPath(
                        for: remoteWallet,
                        keystore: params.keystoreAfterSync
                    )
                    
                    let isEvmDPValid = hasSubstrateDerivPath && hasEvmDerivPath
                    
                    XCTAssert(isEvmDPValid)
                    
                    XCTAssertEqual(updateRemote.syncTime, params.syncMetadataManager.getLastSyncTimestamp())
                    XCTAssertEqual(Self.defaultPassword, try params.syncMetadataManager.getPassword())
                } catch {
                    XCTFail("Error: \(error)")
                }
            }
        )
    }
    
    func testBackupSecretsDerivationPath() throws {
        try performSyncTest(
            configuringLocal: { params in
                try? AccountCreationHelper.createMetaAccountFromMnemonic(
                    cryptoType: .sr25519,
                    derivationPath: "//hard/soft///password",
                    keychain: params.keystore,
                    settings: params.walletSettings
                )
            },
            changingAfterBackup: { params in
                params.syncMetadataManager.saveLastSyncTimestamp(0)
                
                let wallet = params.walletSettings.value!
                params.walletSettings.remove(value: wallet)
                try? KeystoreValidationHelper.clearKeystore(for: wallet, keystore: params.keystore)
                
            },
            validateClosure: { params in
                guard case let .updateLocal(updateLocal) = params.changes else {
                    XCTFail("Expected local update")
                    return
                }
                
                XCTAssertEqual(updateLocal.changes.count, 1)
                
                do {
                    let afterBackupWallets = Set(params.localWalletsAfterSync.map({ $0.info }))
                    
                    let properInsert = try updateLocal.changes.contains { change in
                        switch change {
                        case let .new(remote):
                            let hasDerivPath = try KeystoreValidationHelper.validateMainAccountsHaveDerivationPaths(
                                for: remote,
                                keystore: params.keystoreAfterSync
                            )
                            
                            let hasSecrets = try KeystoreValidationHelper.validateMnemonicSecrets(
                                for: remote,
                                keystore: params.keystoreAfterSync
                            )
                            
                            return afterBackupWallets.contains(remote) && hasSecrets && hasDerivPath
                        default:
                            return false
                        }
                    }
                    
                    XCTAssertTrue(properInsert)
                    
                    XCTAssertEqual(updateLocal.syncTime, params.syncMetadataManager.getLastSyncTimestamp())
                    XCTAssertEqual(Self.defaultPassword, try params.syncMetadataManager.getPassword())
                    XCTAssertEqual(params.backupBeforeSync, params.backupAfterSync)
                    XCTAssertEqual(params.keystoreAfterSetup.getRawStore(), params.keystoreAfterSync.getRawStore())
                } catch {
                    XCTFail("Error: \(error)")
                }
            }
        )
    }
    
    func testBackupSecretsDerivationPathAndChainAccounts() throws {
        try performSyncTest(
            configuringLocal: { params in
                let substrateDerivPath = "//hard/soft///password"
                let ethereumPath = "//44//0//0/0/0"
                
                try? AccountCreationHelper.createMetaAccountFromMnemonic(
                    cryptoType: .sr25519,
                    derivationPath: "//main/test",
                    keychain: params.keystore,
                    settings: params.walletSettings
                )
                
                try? AccountCreationHelper.addMnemonicChainAccount(
                    to: params.walletSettings.value!,
                    chainId: KnowChainId.kusama,
                    cryptoType: .sr25519,
                    derivationPath: substrateDerivPath,
                    keychain: params.keystore,
                    settings: params.walletSettings
                )
                
                try? AccountCreationHelper.addMnemonicChainAccount(
                    to: params.walletSettings.value!,
                    chainId: KnowChainId.ethereum,
                    cryptoType: .ethereumEcdsa,
                    derivationPath: ethereumPath,
                    keychain: params.keystore,
                    settings: params.walletSettings
                )
            },
            changingAfterBackup: { params in
                params.syncMetadataManager.saveLastSyncTimestamp(0)
                
                let wallet = params.walletSettings.value!
                params.walletSettings.remove(value: wallet)
                try? KeystoreValidationHelper.clearKeystore(for: wallet, keystore: params.keystore)
                
            },
            validateClosure: { params in
                guard case let .updateLocal(updateLocal) = params.changes else {
                    XCTFail("Expected local update")
                    return
                }
                
                XCTAssertEqual(updateLocal.changes.count, 1)
                
                do {
                    let afterBackupWallets = Set(params.localWalletsAfterSync.map({ $0.info }))
                    
                    let properInsert = try updateLocal.changes.contains { change in
                        switch change {
                        case let .new(remote):
                            let hasDerivPath = try KeystoreValidationHelper.validateMainAccountsHaveDerivationPaths(
                                for: remote,
                                keystore: params.keystoreAfterSync
                            )
                            
                            let hasDerivChainAccountsPath = try KeystoreValidationHelper.validateChainAccountsHaveDerivationPaths(
                                for: remote,
                                keystore: params.keystoreAfterSync
                            )
                            
                            let hasSecrets = try KeystoreValidationHelper.validateMnemonicSecrets(
                                for: remote,
                                keystore: params.keystoreAfterSync
                            )
                            
                            return afterBackupWallets.contains(remote) && hasSecrets &&
                                hasDerivPath && hasDerivChainAccountsPath
                        default:
                            return false
                        }
                    }
                    
                    XCTAssertTrue(properInsert)
                    
                    XCTAssertEqual(updateLocal.syncTime, params.syncMetadataManager.getLastSyncTimestamp())
                    XCTAssertEqual(Self.defaultPassword, try params.syncMetadataManager.getPassword())
                    XCTAssertEqual(params.backupBeforeSync, params.backupAfterSync)
                    XCTAssertEqual(params.keystoreAfterSetup.getRawStore(), params.keystoreAfterSync.getRawStore())
                } catch {
                    XCTFail("Error: \(error)")
                }
            }
        )
    }
    
    func testBackupSeedWithChainAccounts() throws {
        try performSyncTest(
            configuringLocal: { params in
                let mainSeed = Data.random(of: 32)!
                let substrateSeed = Data.random(of: 32)!
                let ethereumSeed = Data.random(of: 64)!
                
                try? AccountCreationHelper.createMetaAccountFromSeed(
                    mainSeed.toHexString(),
                    cryptoType: .sr25519,
                    keychain: params.keystore,
                    settings: params.walletSettings
                )
                
                try? AccountCreationHelper.addSeedChainAccount(
                    to: params.walletSettings.value!,
                    chainId: KnowChainId.polkadot,
                    seed: substrateSeed.toHexString(),
                    cryptoType: .sr25519,
                    keychain: params.keystore,
                    settings: params.walletSettings
                )
                
                try? AccountCreationHelper.addSeedChainAccount(
                    to: params.walletSettings.value,
                    chainId: KnowChainId.ethereum,
                    seed: ethereumSeed.toHexString(),
                    cryptoType: .ethereumEcdsa,
                    keychain: params.keystore,
                    settings: params.walletSettings
                )
            },
            changingAfterBackup: { params in
                params.syncMetadataManager.saveLastSyncTimestamp(0)
                
                let wallet = params.walletSettings.value!
                params.walletSettings.remove(value: wallet)
                try? KeystoreValidationHelper.clearKeystore(for: wallet, keystore: params.keystore)
                
            },
            validateClosure: { params in
                guard case let .updateLocal(updateLocal) = params.changes else {
                    XCTFail("Expected local update")
                    return
                }
                
                XCTAssertEqual(updateLocal.changes.count, 1)
                
                XCTAssertEqual(updateLocal.syncTime, params.syncMetadataManager.getLastSyncTimestamp())
                XCTAssertEqual(Self.defaultPassword, try? params.syncMetadataManager.getPassword())
                XCTAssertEqual(params.backupBeforeSync, params.backupAfterSync)
                XCTAssertEqual(params.keystoreAfterSetup.getRawStore(), params.keystoreAfterSync.getRawStore())
            }
        )
    }
    
    func testBackupKeystoreWalletWithChainAccounts() throws {
        try performSyncTest(
            configuringLocal: { params in
                let substrateSeed = Data.random(of: 32)!
                let ethereumSeed = Data.random(of: 64)!
                
                try? AccountCreationHelper.createMetaAccountFromKeystore(
                    Constants.validSrKeystoreName,
                    password: Constants.validSrKeystorePassword,
                    keychain: params.keystore,
                    settings: params.walletSettings
                )
                
                try? AccountCreationHelper.addSeedChainAccount(
                    to: params.walletSettings.value!,
                    chainId: KnowChainId.polkadot,
                    seed: substrateSeed.toHexString(),
                    cryptoType: .sr25519,
                    keychain: params.keystore,
                    settings: params.walletSettings
                )
                
                try? AccountCreationHelper.addSeedChainAccount(
                    to: params.walletSettings.value,
                    chainId: KnowChainId.ethereum,
                    seed: ethereumSeed.toHexString(),
                    cryptoType: .ethereumEcdsa,
                    keychain: params.keystore,
                    settings: params.walletSettings
                )
            },
            changingAfterBackup: { params in
                params.syncMetadataManager.saveLastSyncTimestamp(0)
                
                let wallet = params.walletSettings.value!
                params.walletSettings.remove(value: wallet)
                try? KeystoreValidationHelper.clearKeystore(for: wallet, keystore: params.keystore)
                
            },
            validateClosure: { params in
                guard case let .updateLocal(updateLocal) = params.changes else {
                    XCTFail("Expected local update")
                    return
                }
                
                XCTAssertEqual(updateLocal.changes.count, 1)
                
                XCTAssertEqual(updateLocal.syncTime, params.syncMetadataManager.getLastSyncTimestamp())
                XCTAssertEqual(Self.defaultPassword, try? params.syncMetadataManager.getPassword())
                XCTAssertEqual(params.backupBeforeSync, params.backupAfterSync)
                XCTAssertEqual(params.keystoreAfterSetup.getRawStore(), params.keystoreAfterSync.getRawStore())
            }
        )
    }
    
    private func performBackupGenericLedgerWallet(includesEvm: Bool) throws {
        try performSyncTest(
            configuringLocal: { params in
                try? AccountCreationHelper.createGenericLedgerWallet(
                    keychain: params.keystore,
                    settings: params.walletSettings,
                    includesEvm: includesEvm
                )
            },
            changingAfterBackup: { params in
                params.syncMetadataManager.saveLastSyncTimestamp(0)
                
                let wallet = params.walletSettings.value!
                params.walletSettings.remove(value: wallet)
                try? KeystoreValidationHelper.clearKeystore(for: wallet, keystore: params.keystore)
                
            },
            validateClosure: { params in
                guard case let .updateLocal(updateLocal) = params.changes else {
                    XCTFail("Expected local update")
                    return
                }
                
                XCTAssertEqual(updateLocal.changes.count, 1)
                
                do {
                    let afterBackupWallets = Set(params.localWalletsAfterSync.map({ $0.info }))
                    
                    let properInsert = try updateLocal.changes.contains { change in
                        switch change {
                        case let .new(remote):
                            let hasSubstrateDerivPath = try KeystoreValidationHelper.validateMainSubstrateDerivationPath(
                                for: remote,
                                keystore: params.keystoreAfterSync
                            )
                            
                            let hasEvmDerivPath = try KeystoreValidationHelper.validateMainEthereumDerivationPath(
                                for: remote,
                                keystore: params.keystoreAfterSync
                            )
                            
                            let isEvmDPValid = includesEvm ? hasEvmDerivPath : !hasEvmDerivPath
                            
                            return afterBackupWallets.contains(remote) &&
                                hasSubstrateDerivPath &&
                                isEvmDPValid
                        default:
                            return false
                        }
                    }
                    
                    XCTAssertTrue(properInsert)
                    
                    XCTAssertEqual(updateLocal.syncTime, params.syncMetadataManager.getLastSyncTimestamp())
                    XCTAssertEqual(Self.defaultPassword, try params.syncMetadataManager.getPassword())
                    XCTAssertEqual(params.backupBeforeSync, params.backupAfterSync)
                    XCTAssertEqual(params.keystoreAfterSetup.getRawStore(), params.keystoreAfterSync.getRawStore())
                } catch {
                    XCTFail("Error: \(error)")
                }
            }
        )
    }
    
    private func performDetectIssueTest(
        configuringLocal: LocalWalletsSetupClosure
    ) -> CloudBackupSyncResult.Issue? {
        let setupResult = setupSyncSevice(
            configuringLocal: configuringLocal,
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
                return nil
            }
        }
        
        XCTAssertNotNil(syncChanges)
        
        return applyChangesAndDetectIssue(for: setupResult.syncService)
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
        
        let keystoreAfterSetup = MockKeychain(rawStore: setupResult.keystore.getRawStore())
        let keystoreAfterSync = setupResult.keystore
        
        let initChanges: CloudBackupSyncResult.Changes? = syncAndWait(service: setupResult.syncService) { result in
            switch result {
            case let .changes(changes):
                return changes
            default:
                return nil
            }
        }
        
        XCTAssertNotNil(initChanges)
        
        applyChangesAndConfirm(for: setupResult.syncService)
        
        changingAfterBackup(
            .init(
                walletSettings: setupResult.selectedWalletSettings,
                keystore: keystoreAfterSync,
                accountRepositoryFactory: setupResult.accountRepositoryFactory,
                syncMetadataManager: setupResult.syncMetadataManager
            )
        )
        
        let walletsBeforeSync = try WalletsFetchHelper.fetchWallets(using: setupResult.accountRepositoryFactory)
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
        
        applyChangesAndConfirm(for: setupResult.syncService)
        
        let walletsAfterSync = try WalletsFetchHelper.fetchWallets(using: setupResult.accountRepositoryFactory)
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
            keystoreAfterSetup: keystoreAfterSetup,
            keystoreAfterSync: keystoreAfterSync,
            syncMetadataManager: setupResult.syncMetadataManager
        )
        
        validateClosure(validationParams)
    }
    
    private func applyChangesAndConfirm(
        for syncService: CloudBackupSyncServiceProtocol
    ) {
        syncService.applyChanges(notifyingIn: .global(), closure: {_ in })
        
        _ = syncAndWait(service: syncService) { result in
            switch result {
            case .noUpdates:
                return ()
            default:
                return nil
            }
        }
    }
    
    private func applyChangesAndDetectIssue(
        for syncService: CloudBackupSyncServiceProtocol
    ) -> CloudBackupSyncResult.Issue? {
        syncService.applyChanges(notifyingIn: .global(), closure: {_ in })
        
        return syncAndWait(service: syncService) { result in
            switch result {
            case let .issue(issue):
                return issue
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
        
        let keystore = MockKeychain()
        
        let syncMetadataManager = MockCloudBackupSyncMetadataManager()
        
        let walletsRepository = accountsRepositoryFactory.createManagedMetaAccountRepository(
            for: nil,
            sortDescriptors: []
        )
        
        let walletStorageCleaner = WalletStorageCleanerFactory.createTestCleaner(
            operationQueue: operationQueue,
            storageFacade: storageFacade
        )
        
        let walletsUpdater = WalletUpdateMediator(
            selectedWalletSettings: walletSettingsManager,
            repository: walletsRepository,
            walletsCleaner: walletStorageCleaner,
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
        
        let updateCalcFactory = CloudBackupUpdateCalculationFactory(
            syncMetadataManager: syncMetadataManager,
            walletsRepository: accountsRepositoryFactory.createManagedMetaAccountRepository(
                for: NSPredicate.cloudSyncableWallets,
                sortDescriptors: []
            ),
            backupOperationFactory: serviceFactory.createOperationFactory(),
            decodingManager: serviceFactory.createCodingManager(),
            cryptoManager: serviceFactory.createCryptoManager(),
            diffManager: serviceFactory.createDiffCalculator()
        )
        
        let syncService = CloudBackupSyncService(
            updateCalculationFactory: updateCalcFactory,
            applyUpdateFactory: applyFactory,
            syncMetadataManager: syncMetadataManager,
            fileManager: fileManager,
            operationQueue: operationQueue,
            workQueue: .global(),
            logger: Logger.shared
        )
        
        configuringLocal(
            .init(
                walletSettings: walletSettingsManager,
                keystore: keystore
            )
        )
        
        configuringBackup(
            .init(
                serviceFactory: serviceFactory,
                keystore: keystore,
                syncMetadataManager: syncMetadataManager
            )
        )
        
        return SyncSetupResult(
            syncService: syncService,
            syncMetadataManager: syncMetadataManager,
            serviceFactory: serviceFactory,
            selectedWalletSettings: walletSettingsManager,
            accountRepositoryFactory: accountsRepositoryFactory,
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
        
        service.subscribeState(
            self,
            notifyingIn: .main
        ) { result in
            if 
                case .enabled(let optSyncResult, _) = result,
                let syncResult = optSyncResult,
                let value = closure(syncResult) {
                resultValue = value
                expectation.fulfill()
            }
        }
        
        service.syncUp()
        
        wait(for: [expectation], timeout: timeout)
        
        service.unsubscribeState(self)
        
        return resultValue
    }
}
