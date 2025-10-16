import XCTest
@testable import novawallet
import Keystore_iOS
import Operation_iOS
import Cuckoo

final class WalletNotificationsCleaningTests: XCTestCase {
    // MARK: - Test Cases

    func testRemovedWalletNotificationsCleanerRemovesSettingsForDeletedWallets() throws {
        // given
        let operationQueue = OperationQueue()
        let context = TestContext.createForRemoval(using: operationQueue)

        let removedWallet = createTestWallet()
        let keepWallet = createTestWallet(isSelected: true, order: 1)

        let removedWalletLocal = createLocalWallet(for: removedWallet)
        let keepWalletLocal = createLocalWallet(for: keepWallet)

        let settingsCollector = stubNotificationsFacadeForSave(context.notificationsFacade)

        try setupInitialSettings(
            context: context,
            wallets: [keepWalletLocal, removedWalletLocal]
        )

        let providers = createProviders(
            changes: [.delete(deletedIdentifier: removedWallet.identifier)],
            walletsBeforeChanges: [
                removedWallet.identifier: removedWallet,
                keepWallet.identifier: keepWallet
            ]
        )

        // when
        let wrapper = context.cleaner.cleanStorage(using: providers)
        try executeAndWait(wrapper: wrapper, in: context.operationQueue)

        // then
        XCTAssertNotNil(settingsCollector.settings)
        XCTAssertEqual(settingsCollector.settings?.accountBased.wallets.count, 1)
        XCTAssertEqual(settingsCollector.settings?.accountBased.wallets.first?.metaId, keepWallet.info.metaId)
        verify(context.notificationsFacade, times(1)).save(settings: any(), completion: any())
    }

    func testRemovedWalletNotificationsCleanerSkipsWhenNoWalletsRemoved() throws {
        // given
        let operationQueue = OperationQueue()
        let context = TestContext.createForRemoval(using: operationQueue)

        let wallet = createTestWallet(isSelected: true)
        let walletLocal = createLocalWallet(for: wallet)

        try setupInitialSettings(context: context, wallets: [walletLocal])

        stub(context.notificationsFacade) { stub in
            when(stub.save(settings: any(), completion: any())).then { _, completion in
                completion(.success(()))
            }
        }

        let providers = createProviders(
            changes: [],
            walletsBeforeChanges: [wallet.identifier: wallet]
        )

        // when
        let wrapper = context.cleaner.cleanStorage(using: providers)
        try executeAndWait(wrapper: wrapper, in: context.operationQueue)

        // then
        verify(context.notificationsFacade, never()).save(settings: any(), completion: any())
    }

    func testUpdatedWalletNotificationsCleanerUpdatesWhenChainAccountsChange() throws {
        // given
        let operationQueue = OperationQueue()
        let context = TestContext.createForUpdate(using: operationQueue)
        let knownChainId = KnowChainId.polkadot

        let (originalWallet, originalChainAccount) = createTestWalletWithChainAccount(chainId: knownChainId)

        let updatedChainAccount = AccountGenerator.generateChainAccount(with: knownChainId)
        let updatedInfo = originalWallet.info.replacingChainAccount(updatedChainAccount)
        let updatedWallet = originalWallet.replacingInfo(updatedInfo)

        let initialWalletLocal = createLocalWallet(
            for: originalWallet,
            chainSpecific: [knownChainId: try! originalChainAccount.accountId.toAddressWithDefaultConversion()]
        )

        try setupInitialSettings(
            context: context,
            wallets: [initialWalletLocal],
            chainId: knownChainId
        )

        let settingsCollector = stubNotificationsFacadeForSave(context.notificationsFacade)

        let providers = createProviders(
            changes: [.update(newItem: updatedWallet)],
            walletsBeforeChanges: [originalWallet.identifier: originalWallet]
        )

        // when
        let wrapper = context.cleaner.cleanStorage(using: providers)
        try executeAndWait(wrapper: wrapper, in: context.operationQueue)

        // then
        XCTAssertNotNil(settingsCollector.settings)
        XCTAssertEqual(settingsCollector.settings?.accountBased.wallets.count, 1)
        XCTAssertEqual(settingsCollector.settings?.accountBased.wallets.first?.metaId, updatedWallet.info.metaId)

        let savedChainSpecific = settingsCollector.settings?.accountBased.wallets.first?.model.chainSpecific
        XCTAssertEqual(
            savedChainSpecific?[knownChainId],
            try! updatedChainAccount.accountId.toAddressWithDefaultConversion()
        )

        verify(context.notificationsFacade, times(1)).save(settings: any(), completion: any())
    }

    func testUpdatedWalletNotificationsCleanerSkipsWhenChainAccountsUnchanged() throws {
        // given
        let operationQueue = OperationQueue()
        let context = TestContext.createForUpdate(using: operationQueue)

        let originalWallet = createTestWallet(isSelected: true, chainAccounts: 1)
        let updatedInfo = originalWallet.info.replacingName(with: "New Name")
        let updatedWallet = originalWallet.replacingInfo(updatedInfo)

        let initialWalletLocal = createLocalWallet(for: originalWallet)

        try setupInitialSettings(context: context, wallets: [initialWalletLocal])

        stub(context.notificationsFacade) { stub in
            when(stub.save(settings: any(), completion: any())).thenDoNothing()
        }

        let providers = createProviders(
            changes: [.update(newItem: updatedWallet)],
            walletsBeforeChanges: [originalWallet.identifier: originalWallet]
        )

        // when
        let wrapper = context.cleaner.cleanStorage(using: providers)
        try executeAndWait(wrapper: wrapper, in: context.operationQueue)

        // then
        verify(context.notificationsFacade, never()).save(settings: any(), completion: any())
    }
}

// MARK: - Private

private extension WalletNotificationsCleaningTests {
    struct TestContext {
        let operationQueue: OperationQueue
        let notificationsRepository: AnyDataProviderRepository<Web3Alert.LocalSettings>
        let topicsRepository: AnyDataProviderRepository<PushNotification.TopicSettings>
        let notificationsFacade: MockPushNotificationsServiceFacadeProtocol
        let settingsManager: SettingsManagerProtocol
        let chainRepository: AnyDataProviderRepository<ChainModel>?
        let cleaner: WalletStorageCleaning

        static func createForRemoval(using operationQueue: OperationQueue) -> TestContext {
            let context = createBaseContext(using: operationQueue)

            let cleaner = RemovedWalletNotificationsCleaner(
                notificationsSettingsRepository: context.notificationsRepository,
                notificationsTopicsRepository: context.topicsRepository,
                notificationsFacade: context.notificationsFacade,
                settingsManager: context.settingsManager,
                operationQueue: operationQueue
            )

            return TestContext(
                operationQueue: operationQueue,
                notificationsRepository: context.notificationsRepository,
                topicsRepository: context.topicsRepository,
                notificationsFacade: context.notificationsFacade,
                settingsManager: context.settingsManager,
                chainRepository: nil,
                cleaner: cleaner
            )
        }

        static func createForUpdate(using operationQueue: OperationQueue) -> TestContext {
            let context = createBaseContext(using: operationQueue)
            let substrateStorageFacade = SubstrateStorageTestFacade()

            let chainRepository = AnyDataProviderRepository(
                substrateStorageFacade.createRepository(
                    mapper: AnyCoreDataMapper(ChainModelMapper())
                )
            )

            let cleaner = UpdatedWalletNotificationsCleaner(
                pushNotificationSettingsFactory: PushNotificationSettingsFactory(),
                chainRepository: chainRepository,
                notificationsSettingsRepository: context.notificationsRepository,
                notificationsTopicsRepository: context.topicsRepository,
                notificationsFacade: context.notificationsFacade,
                settingsManager: context.settingsManager,
                operationQueue: operationQueue
            )

            return TestContext(
                operationQueue: operationQueue,
                notificationsRepository: context.notificationsRepository,
                topicsRepository: context.topicsRepository,
                notificationsFacade: context.notificationsFacade,
                settingsManager: context.settingsManager,
                chainRepository: chainRepository,
                cleaner: cleaner
            )
        }

        private static func createBaseContext(using _: OperationQueue) -> (
            notificationsRepository: AnyDataProviderRepository<Web3Alert.LocalSettings>,
            topicsRepository: AnyDataProviderRepository<PushNotification.TopicSettings>,
            notificationsFacade: MockPushNotificationsServiceFacadeProtocol,
            settingsManager: SettingsManagerProtocol
        ) {
            let userStorageFacade = UserDataStorageTestFacade()

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

            let notificationsFacade = MockPushNotificationsServiceFacadeProtocol()
            let settingsManager = InMemorySettingsManager()

            settingsManager.notificationsEnabled = true

            return (notificationsRepository, topicsRepository, notificationsFacade, settingsManager)
        }
    }

    class SavedSettingsCollector {
        var settings: PushNotification.AllSettings?
    }

    // MARK: - Helpers

    func createTestWallet(
        isSelected: Bool = false,
        order: UInt32 = 0,
        chainAccounts: Int = 0
    ) -> ManagedMetaAccountModel {
        ManagedMetaAccountModel(
            info: AccountGenerator.generateMetaAccount(generatingChainAccounts: chainAccounts),
            isSelected: isSelected,
            order: order
        )
    }

    func createTestWalletWithChainAccount(
        isSelected: Bool = true,
        order: UInt32 = 0,
        chainId: ChainModel.Id
    ) -> (wallet: ManagedMetaAccountModel, chainAccount: ChainAccountModel) {
        let chainAccount = AccountGenerator.generateChainAccount(with: chainId)
        let wallet = ManagedMetaAccountModel(
            info: AccountGenerator.generateMetaAccount(with: [chainAccount]),
            isSelected: isSelected,
            order: order
        )
        return (wallet, chainAccount)
    }

    func createLocalWallet(
        for wallet: ManagedMetaAccountModel,
        chainSpecific: [String: String] = [:]
    ) -> Web3Alert.LocalWallet {
        Web3Alert.LocalWallet(
            metaId: wallet.info.metaId,
            model: Web3Alert.Wallet(
                baseSubstrate: nil,
                baseEthereum: nil,
                chainSpecific: chainSpecific
            )
        )
    }

    func createProviders(
        changes: [DataProviderChange<ManagedMetaAccountModel>],
        walletsBeforeChanges: [String: ManagedMetaAccountModel]
    ) -> WalletStorageCleaningProviders {
        WalletStorageCleaningProviders(
            changesProvider: { changes },
            walletsBeforeChangesProvider: { walletsBeforeChanges }
        )
    }

    func setupInitialSettings(
        context: TestContext,
        wallets: [Web3Alert.LocalWallet],
        chainId: ChainModel.Id? = nil
    ) throws {
        let wrapper = createInitialSettingsSetupWrapper(
            context: context,
            wallets: wallets,
            chainId: chainId
        )

        try executeAndWait(wrapper: wrapper, in: context.operationQueue)
    }

    func createInitialSettingsSetupWrapper(
        context: TestContext,
        wallets: [Web3Alert.LocalWallet],
        chainId: ChainModel.Id? = nil
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

        let saveSettingsOperation = context.notificationsRepository.saveOperation(
            { [initialSettings] },
            { [] }
        )

        let saveTopicsOperation = context.topicsRepository.saveOperation(
            { [PushNotification.TopicSettings(topics: [])] },
            { [] }
        )

        var allOperations = [saveSettingsOperation, saveTopicsOperation]

        // Add chain setup if needed
        if let chainId, let chainRepository = context.chainRepository {
            let chain = ChainModelGenerator.generateChain(
                defaultChainId: chainId,
                generatingAssets: 2,
                addressPrefix: ChainModel.AddressPrefix(0),
                hasCrowdloans: true
            )

            let chainSaveOperation = chainRepository.saveOperation({ [chain] }, { [] })
            allOperations.append(chainSaveOperation)
        }

        let resultOperation = ClosureOperation<Void> {
            for operation in allOperations {
                try operation.extractNoCancellableResultData()
            }
        }

        allOperations.forEach { resultOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: allOperations
        )
    }

    func executeAndWait(
        wrapper: CompoundOperationWrapper<Void>,
        in queue: OperationQueue,
        timeout: TimeInterval = 10.0
    ) throws {
        let expectation = XCTestExpectation()

        wrapper.targetOperation.completionBlock = {
            expectation.fulfill()
        }

        queue.addOperations(wrapper.allOperations, waitUntilFinished: false)
        wait(for: [expectation], timeout: timeout)

        XCTAssertNoThrow(try wrapper.targetOperation.extractNoCancellableResultData())
    }

    func stubNotificationsFacadeForSave(
        _ facade: MockPushNotificationsServiceFacadeProtocol
    ) -> SavedSettingsCollector {
        let collector = SavedSettingsCollector()
        stub(facade) { stub in
            when(stub.save(settings: any(), completion: any())).then { settings, completion in
                collector.settings = settings
                completion(.success(()))
            }
        }

        return collector
    }
}
