import Foundation
import Keystore_iOS
import Operation_iOS

struct AssetExchangeGraphProvidingParams {
    let wallet: MetaAccountModel
    let substrateStorageFacade: StorageFacadeProtocol
    let userDataStorageFacade: StorageFacadeProtocol
    let chainRegistry: ChainRegistryProtocol
    let config: ApplicationConfigProtocol
    let operationQueue: OperationQueue
    let keychain: KeystoreProtocol
    let settingsManager: SettingsManagerProtocol
    let signingWrapperFactory: SigningWrapperFactoryProtocol
    let logger: LoggerProtocol

    init(
        wallet: MetaAccountModel,
        substrateStorageFacade: StorageFacadeProtocol = SubstrateDataStorageFacade.shared,
        userDataStorageFacade: StorageFacadeProtocol = UserDataStorageFacade.shared,
        chainRegistry: ChainRegistryProtocol = ChainRegistryFacade.sharedRegistry,
        config: ApplicationConfigProtocol = ApplicationConfig.shared,
        operationQueue: OperationQueue = OperationManagerFacade.sharedDefaultQueue,
        keychain: KeystoreProtocol = Keychain(),
        settingsManager: SettingsManagerProtocol = SettingsManager.shared,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.wallet = wallet
        self.substrateStorageFacade = substrateStorageFacade
        self.userDataStorageFacade = userDataStorageFacade
        self.chainRegistry = chainRegistry
        self.config = config
        self.operationQueue = operationQueue
        self.keychain = keychain
        self.settingsManager = settingsManager

        signingWrapperFactory = SigningWrapperFactory(
            keystore: keychain,
            settingsManager: settingsManager
        )

        self.logger = logger
    }
}
