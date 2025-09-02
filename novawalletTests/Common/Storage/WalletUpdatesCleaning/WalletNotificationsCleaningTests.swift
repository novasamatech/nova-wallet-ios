import XCTest
@testable import novawallet
import Keystore_iOS
import Operation_iOS
import Cuckoo

final class WalletNotificationsCleaningTests: XCTestCase {
    func testRemovedWalletNotificationsCleanerRemovesSettingsForDeletedWallets() throws {
        // given
        let operationQueue = OperationQueue()
        let common = Common.createRemoveDependencies(using: operationQueue)
        
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
        
        let removedWalletLocal = Web3Alert.LocalWallet(
            metaId: removedWallet.info.metaId,
            model: Web3Alert.Wallet(
                baseSubstrate: nil,
                baseEthereum: nil,
                chainSpecific: [:]
            )
        )
        let keepWalletLocal = Web3Alert.LocalWallet(
            metaId: keepWallet.info.metaId,
            model: Web3Alert.Wallet(
                baseSubstrate: nil,
                baseEthereum: nil,
                chainSpecific: [:]
            )
        )
        
        var savedSettings: PushNotification.AllSettings?
        stub(common.notificationsFacade) { stub in
            when(stub.save(settings: any(), completion: any())).then { settings, completion in
                savedSettings = settings
                completion(.success(()))
            }
        }
        
        let setupExpectation = XCTestExpectation()
        
        let setupWrapper = setupRemovedWalletCommonLocalSettings(
            for: common,
            wallets: [keepWalletLocal, removedWalletLocal]
        )
        setupWrapper.targetOperation.completionBlock = {
            setupExpectation.fulfill()
        }
        
        operationQueue.addOperations(setupWrapper.allOperations, waitUntilFinished: false)
        
        wait(for: [setupExpectation], timeout: 10.0)
        
        let providers = WalletStorageCleaningProviders(
            changesProvider: {
                [DataProviderChange.delete(deletedIdentifier: removedWallet.identifier)]
            },
            walletsBeforeChangesProvider: {
                [removedWallet.identifier: removedWallet, keepWallet.identifier: keepWallet]
            }
        )
        
        // when
        let cleanerExpectation = XCTestExpectation()
        
        let wrapper = common.cleaner.cleanStorage(using: providers)
        wrapper.targetOperation.completionBlock = {
            cleanerExpectation.fulfill()
        }
        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
        wait(for: [cleanerExpectation], timeout: 10.0)
        
        // then
        XCTAssertNoThrow(try wrapper.targetOperation.extractNoCancellableResultData())
        XCTAssertNotNil(savedSettings)
        XCTAssertEqual(savedSettings?.accountBased.wallets.count, 1)
        XCTAssertEqual(savedSettings?.accountBased.wallets.first?.metaId, keepWallet.info.metaId)
        verify(common.notificationsFacade, times(1)).save(settings: any(), completion: any())
    }
        
    func testRemovedWalletNotificationsCleanerSkipsWhenNoWalletsRemoved() throws {
        // given
        let operationQueue = OperationQueue()
        let common = Common.createRemoveDependencies(using: operationQueue)
        
        let wallet = ManagedMetaAccountModel(
            info: AccountGenerator.generateMetaAccount(generatingChainAccounts: 0),
            isSelected: true,
            order: 0
        )
        
        let walletLocal = Web3Alert.LocalWallet(
            metaId: wallet.info.metaId,
            model: Web3Alert.Wallet(
                baseSubstrate: nil,
                baseEthereum: nil,
                chainSpecific: [:]
            )
        )
        
        let setupExpectation = XCTestExpectation()
        
        let setupWrapper = setupRemovedWalletCommonLocalSettings(
            for: common,
            wallets: [walletLocal]
        )
        setupWrapper.targetOperation.completionBlock = {
            setupExpectation.fulfill()
        }
        
        operationQueue.addOperations(setupWrapper.allOperations, waitUntilFinished: false)
        
        wait(for: [setupExpectation], timeout: 10.0)
        
        stub(common.notificationsFacade) { stub in
            when(stub.save(settings: any(), completion: any())).then { _, completion in
                completion(.success(()))
            }
        }
        
        let providers = WalletStorageCleaningProviders(
            changesProvider: { [] },
            walletsBeforeChangesProvider: { [wallet.identifier: wallet] }
        )
        
        // when
        let cleanerExpectation = XCTestExpectation()
        
        let wrapper = common.cleaner.cleanStorage(using: providers)
        wrapper.targetOperation.completionBlock = {
            cleanerExpectation.fulfill()
        }
        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
        wait(for: [cleanerExpectation], timeout: 10.0)
        
        // then
        XCTAssertNoThrow(try wrapper.targetOperation.extractNoCancellableResultData())
        verify(common.notificationsFacade, never()).save(settings: any(), completion: any())
    }
    
    func testUpdatedWalletNotificationsCleanerUpdatesWhenChainAccountsChange() throws {
        // given
        let operationQueue = OperationQueue()
        let common = Common.createUpdateDependencies(using: operationQueue)
        
        let knownChainId = KnowChainId.polkadot
        
        let originalChainAccount = AccountGenerator.generateChainAccount(with: knownChainId)
        let originalWallet = ManagedMetaAccountModel(
            info: AccountGenerator.generateMetaAccount(with: [originalChainAccount]),
            isSelected: true,
            order: 0
        )
        
        let updatedChainAccount = AccountGenerator.generateChainAccount(with: knownChainId)
        let updatedInfo = originalWallet.info.replacingChainAccount(updatedChainAccount)
        let updatedWallet = originalWallet.replacingInfo(updatedInfo)
        
        let initialWalletLocal = Web3Alert.LocalWallet(
            metaId: originalWallet.info.metaId,
            model: Web3Alert.Wallet(
                baseSubstrate: nil,
                baseEthereum: nil,
                chainSpecific: [knownChainId: try! originalChainAccount.accountId.toAddressWithDefaultConversion()]
            )
        )
        
        let setupExpectation = XCTestExpectation()
        
        let setupWrapper = setupUpdatedWalletCommonLocalSettings(
            for: common,
            wallets: [initialWalletLocal],
            chainId: knownChainId
        )
        setupWrapper.targetOperation.completionBlock = {
            setupExpectation.fulfill()
        }
        
        operationQueue.addOperations(setupWrapper.allOperations, waitUntilFinished: false)
        
        wait(for: [setupExpectation], timeout: 10.0)
        
        var savedSettings: PushNotification.AllSettings?
        stub(common.notificationsFacade) { stub in
            when(stub.save(settings: any(), completion: any())).then { settings, completion in
                savedSettings = settings
                completion(.success(()))
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
        
        // when
        let cleanerExpectation = XCTestExpectation()
        
        let wrapper = common.cleaner.cleanStorage(using: providers)
        wrapper.targetOperation.completionBlock = {
            cleanerExpectation.fulfill()
        }
        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
        wait(for: [cleanerExpectation], timeout: 10.0)
        
        // then
        XCTAssertNoThrow(try wrapper.targetOperation.extractNoCancellableResultData())
        XCTAssertNotNil(savedSettings)
        
        XCTAssertEqual(savedSettings?.accountBased.wallets.count, 1)
        XCTAssertEqual(savedSettings?.accountBased.wallets.first?.metaId, updatedWallet.info.metaId)
        
        let savedChainSpecific = savedSettings?.accountBased.wallets.first?.model.chainSpecific
        XCTAssertEqual(
            savedChainSpecific?[knownChainId],
            try! updatedChainAccount.accountId.toAddressWithDefaultConversion()
        )
        
        verify(common.notificationsFacade, times(1)).save(settings: any(), completion: any())
    }

    func testUpdatedWalletNotificationsCleanerSkipsWhenChainAccountsUnchanged() throws {
        // given
        let operationQueue = OperationQueue()
        let common = Common.createUpdateDependencies(using: operationQueue)
        
        let originalWallet = ManagedMetaAccountModel(
            info: AccountGenerator.generateMetaAccount(generatingChainAccounts: 1),
            isSelected: true,
            order: 0
        )
        
        let updatedInfo = originalWallet.info.replacingName(with: "New Name")
        let updatedWallet = originalWallet.replacingInfo(updatedInfo)
        
        let initialWalletLocal = Web3Alert.LocalWallet(
            metaId: originalWallet.info.metaId,
            model: Web3Alert.Wallet(
                baseSubstrate: nil,
                baseEthereum: nil,
                chainSpecific: [:]
            )
        )
        
        let setupExpectation = XCTestExpectation()
        
        let setupWrapper = setupUpdatedWalletCommonLocalSettings(
            for: common,
            wallets: [initialWalletLocal]
        )
        setupWrapper.targetOperation.completionBlock = {
            setupExpectation.fulfill()
        }
        
        operationQueue.addOperations(setupWrapper.allOperations, waitUntilFinished: false)
        
        wait(for: [setupExpectation], timeout: 10.0)
        
        stub(common.notificationsFacade) { stub in
            when(stub.save(settings: any(), completion: any())).thenDoNothing()
        }
        
        let providers = WalletStorageCleaningProviders(
            changesProvider: {
                [DataProviderChange.update(newItem: updatedWallet)]
            },
            walletsBeforeChangesProvider: {
                [originalWallet.identifier: originalWallet]
            }
        )
        
        // when
        let cleanerExpectation = XCTestExpectation()
        
        let wrapper = common.cleaner.cleanStorage(using: providers)
        wrapper.targetOperation.completionBlock = {
            cleanerExpectation.fulfill()
        }
        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
        wait(for: [cleanerExpectation], timeout: 10.0)
        
        // then
        XCTAssertNoThrow(try wrapper.targetOperation.extractNoCancellableResultData())
        verify(common.notificationsFacade, never()).save(settings: any(), completion: any())
    }

}

// MARK: - Common

extension WalletNotificationsCleaningTests {
    struct Common {
        let operationQueue: OperationQueue
        let notificationsRepository: AnyDataProviderRepository<Web3Alert.LocalSettings>
        let topicsRepository: AnyDataProviderRepository<PushNotification.TopicSettings>
        let notificationsFacade: MockPushNotificationsServiceFacadeProtocol
        let settingsManager: MockSettingsManagerProtocol
        let chainRepository: AnyDataProviderRepository<ChainModel>?
        let cleaner: WalletStorageCleaning
        
        static func createRemoveDependencies(using operationQueue: OperationQueue) -> Common {
            let facade = UserDataStorageTestFacade()
            
            let notificationsRepository = AnyDataProviderRepository(
                facade.createRepository(
                    filter: .pushSettings,
                    sortDescriptors: [],
                    mapper: AnyCoreDataMapper(Web3AlertSettingsMapper())
                )
            )
            let topicsRepository = AnyDataProviderRepository(
                facade.createRepository(
                    filter: .topicSettings,
                    sortDescriptors: [],
                    mapper: AnyCoreDataMapper(Web3TopicSettingsMapper())
                )
            )
            
            let notificationsFacade = MockPushNotificationsServiceFacadeProtocol()
            let settingsManager = MockSettingsManagerProtocol()
            
            stub(settingsManager) { stub in
                when(stub.bool(for: SettingsKey.notificationsEnabled.rawValue)).thenReturn(true)
            }
            
            let cleaner = RemovedWalletNotificationsCleaner(
                notificationsSettingsRepository: notificationsRepository,
                notificationsTopicsRepository: topicsRepository,
                notificationsFacade: notificationsFacade,
                settingsManager: settingsManager,
                operationQueue: operationQueue
            )
            
            return Common(
                operationQueue: operationQueue,
                notificationsRepository: notificationsRepository,
                topicsRepository: topicsRepository,
                notificationsFacade: notificationsFacade,
                settingsManager: settingsManager,
                chainRepository: nil,
                cleaner: cleaner
            )
        }
        
        static func createUpdateDependencies(using operationQueue: OperationQueue) -> Common {
            let userStorageFacade = UserDataStorageTestFacade()
            let substrateStorageFacade = SubstrateStorageTestFacade()
            
            let notificationsRepository = AnyDataProviderRepository(
                userStorageFacade.createRepository(
                    filter: .pushSettings,
                    sortDescriptors: [],
                    mapper: AnyCoreDataMapper(Web3AlertSettingsMapper())
                )
            )
            let topicsRepository = AnyDataProviderRepository(
                userStorageFacade.createRepository(
                    filter: .topicSettings,
                    sortDescriptors: [],
                    mapper: AnyCoreDataMapper(Web3TopicSettingsMapper())
                )
            )
            let chainRepository = AnyDataProviderRepository(
                substrateStorageFacade.createRepository(
                    mapper: AnyCoreDataMapper(ChainModelMapper())
                )
            )
            
            let notificationsFacade = MockPushNotificationsServiceFacadeProtocol()
            let settingsManager = MockSettingsManagerProtocol()
            
            stub(settingsManager) { stub in
                when(stub.bool(for: SettingsKey.notificationsEnabled.rawValue)).thenReturn(true)
            }
            
            let cleaner = UpdatedWalletNotificationsCleaner(
                pushNotificationSettingsFactory: PushNotificationSettingsFactory(),
                chainRepository: chainRepository,
                notificationsSettingsRepository: notificationsRepository,
                notificationsTopicsRepository: topicsRepository,
                notificationsFacade: notificationsFacade,
                settingsManager: settingsManager,
                operationQueue: operationQueue
            )
            
            return Common(
                operationQueue: operationQueue,
                notificationsRepository: notificationsRepository,
                topicsRepository: topicsRepository,
                notificationsFacade: notificationsFacade,
                settingsManager: settingsManager,
                chainRepository: chainRepository,
                cleaner: cleaner
            )
        }
    }
    
    func setupWalletCommonLocalSettings(
        for dependencies: Common,
        wallets: [Web3Alert.LocalWallet]
    ) -> CompoundOperationWrapper<Void> {
        let initialSettings = Web3Alert.LocalSettings(
            remoteIdentifier: UUID().uuidString,
            pushToken: "test-token",
            updatedAt: Date(),
            wallets: wallets,
            notifications: Web3Alert.LocalNotifications(
                stakingReward: .all,
                tokenSent: .all,
                tokenReceived: .all
            )
        )
        
        let saveSettingsOperation = dependencies.notificationsRepository.saveOperation(
            { [initialSettings] },
            { [] }
        )
        let saveTopicsOperation = dependencies.topicsRepository.saveOperation(
            { [PushNotification.TopicSettings(topics: [])] },
            { [] }
        )
        let resultOperation = ClosureOperation<Void> {
            try saveSettingsOperation.extractNoCancellableResultData()
            try saveTopicsOperation.extractNoCancellableResultData()
        }
        
        resultOperation.addDependency(saveSettingsOperation)
        resultOperation.addDependency(saveTopicsOperation)
        
        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: [saveSettingsOperation, saveTopicsOperation]
        )
    }
    
    func setupRemovedWalletCommonLocalSettings(
        for dependencies: Common,
        wallets: [Web3Alert.LocalWallet]
    ) -> CompoundOperationWrapper<Void> {
        setupWalletCommonLocalSettings(
            for: dependencies,
            wallets: wallets
        )
    }
    
    func setupUpdatedWalletCommonLocalSettings(
        for dependencies: Common,
        wallets: [Web3Alert.LocalWallet],
        chainId: ChainModel.Id? = nil
    ) -> CompoundOperationWrapper<Void> {
        let commonSetupWrapper = setupWalletCommonLocalSettings(
            for: dependencies,
            wallets: wallets
        )
        
        guard let chainRepository = dependencies.chainRepository else {
            return commonSetupWrapper
        }
        
        let chain = ChainModelGenerator.generateChain(
            defaultChainId: chainId,
            generatingAssets: 2,
            addressPrefix: ChainModel.AddressPrefix(0),
            hasCrowdloans: true
        )
        
        let chainSaveOperation = chainRepository.saveOperation(
            { [chain] },
            { [] }
        )
        
        let resultOperation = ClosureOperation<Void> {
            try commonSetupWrapper.targetOperation.extractNoCancellableResultData()
            try chainSaveOperation.extractNoCancellableResultData()
        }
        
        resultOperation.addDependency(commonSetupWrapper.targetOperation)
        resultOperation.addDependency(chainSaveOperation)
        
        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: commonSetupWrapper.allOperations + [chainSaveOperation]
        )
    }
}
