import Operation_iOS
import Keystore_iOS
import Foundation

protocol PushNotificationsHandlerFactoryProtocol {
    func createHandler(message: NotificationMessage) -> PushNotificationMessageHandlingProtocol?
}

final class PushNotificationsHandlerFactory {
    private let chainRegistryClosure: ChainRegistryLazyClosure
    private let settings: SettingsManagerProtocol
    private let operationQueue: OperationQueue
    private let workingQueue: DispatchQueue
    private let walletSettings: SelectedWalletSettings
    private let userDataStorageFacade: StorageFacadeProtocol
    private let eventCenter: EventCenterProtocol

    init(
        chainRegistryClosure: @escaping ChainRegistryLazyClosure,
        settings: SettingsManagerProtocol = SettingsManager.shared,
        operationQueue: OperationQueue = OperationManagerFacade.sharedDefaultQueue,
        workingQueue: DispatchQueue = .main,
        walletSettings: SelectedWalletSettings = SelectedWalletSettings.shared,
        eventCenter: EventCenterProtocol = EventCenter.shared,
        userDataStorageFacade: StorageFacadeProtocol = UserDataStorageFacade.shared
    ) {
        self.chainRegistryClosure = chainRegistryClosure
        self.settings = settings
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
        self.walletSettings = walletSettings
        self.eventCenter = eventCenter
        self.userDataStorageFacade = userDataStorageFacade
    }
}

// MARK: - Private

private extension PushNotificationsHandlerFactory {
    func createAssetDetailsHandler() -> PushNotificationMessageHandlingProtocol {
        let chainRegistry = chainRegistryClosure()
        let settingsRepository = userDataStorageFacade.createRepository(
            filter: .pushSettings,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(Web3AlertSettingsMapper())
        )
        let walletsRepository = userDataStorageFacade.createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(MetaAccountMapper())
        )
        return AssetDetailsNotificationMessageHandler(
            chainRegistry: chainRegistry,
            settings: walletSettings,
            eventCenter: eventCenter,
            settingsRepository: AnyDataProviderRepository(settingsRepository),
            walletsRepository: AnyDataProviderRepository(walletsRepository),
            operationQueue: operationQueue,
            workingQueue: workingQueue
        )
    }

    func createGovernanceHandler() -> PushNotificationMessageHandlingProtocol {
        let chainRegistry = chainRegistryClosure()
        return GovernanceNotificationMessageHandler(chainRegistry: chainRegistry, settings: settings)
    }

    func createMultisigHandler() -> PushNotificationMessageHandlingProtocol {
        let chainRegistry = chainRegistryClosure()
        let settingsRepository = userDataStorageFacade.createRepository(
            filter: .pushSettings,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(Web3AlertSettingsMapper())
        )
        let walletsCoreDataRepository = userDataStorageFacade.createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(MetaAccountMapper())
        )
        let walletsRepository = AnyDataProviderRepository(walletsCoreDataRepository)

        let chainProvider = ChainRegistryChainProvider(chainRegistry: chainRegistry)
        let runtimeCodingServiceProvider = ChainRegistryRuntimeCodingServiceProvider(chainRegistry: chainRegistry)

        let callFormattingFactory = CallFormattingOperationFactory(
            chainProvider: chainProvider,
            runtimeCodingServiceProvider: runtimeCodingServiceProvider,
            walletRepository: walletsRepository,
            operationQueue: operationQueue
        )

        return MultisigNotificationMessageHandler(
            chainRegistry: chainRegistry,
            settings: walletSettings,
            eventCenter: eventCenter,
            settingsRepository: AnyDataProviderRepository(settingsRepository),
            walletsRepository: walletsRepository,
            callFormattingFactory: callFormattingFactory,
            operationQueue: operationQueue,
            workingQueue: workingQueue
        )
    }
}

// MARK: - PushNotificationsHandlerFactoryProtocol

extension PushNotificationsHandlerFactory: PushNotificationsHandlerFactoryProtocol {
    func createHandler(message: NotificationMessage) -> PushNotificationMessageHandlingProtocol? {
        switch message {
        case .transfer, .stakingReward:
            createAssetDetailsHandler()
        case .newReferendum, .referendumUpdate:
            createGovernanceHandler()
        case .newMultisig, .multisigApproval, .multisigExecuted, .multisigCancelled:
            createMultisigHandler()
        case .newRelease:
            nil
        }
    }
}
