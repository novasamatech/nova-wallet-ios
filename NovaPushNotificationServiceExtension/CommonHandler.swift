import RobinHood
import SoraFoundation

class CommonHandler {
    let userStorageFacade: StorageFacadeProtocol
    let substrateStorageFacade: StorageFacadeProtocol
    
    lazy var settingsRepository: AnyDataProviderRepository<LocalPushSettings> = createSettingsRepository()
    lazy var chainsRepository: AnyDataProviderRepository<ChainModel> = createChainsRepository()
    
    init(userStorageFacade: StorageFacadeProtocol = UserDataStorageFacade.shared,
         substrateStorageFacade: StorageFacadeProtocol = SubstrateDataStorageFacade.shared
    ) {
        self.userStorageFacade = userStorageFacade
        self.substrateStorageFacade = substrateStorageFacade
    }
    
    func createSettingsRepository() -> AnyDataProviderRepository<LocalPushSettings> {
        let pushSettings = NSPredicate(format: "%K == %@", 
                                       #keyPath(CDUserSingleValue.identifier),
                                       LocalPushSettings.getIdentifier())
        
        let repository: CoreDataRepository<LocalPushSettings, CDUserSingleValue> =
        userStorageFacade.createRepository(
            filter: pushSettings,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(Web3AlertSettingsMapper())
        )
        
        return AnyDataProviderRepository(repository)
    }
    
    func createChainsRepository() -> AnyDataProviderRepository<ChainModel> {
        let mapper = ChainModelMapper()
        let repository = substrateStorageFacade.createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        return AnyDataProviderRepository(repository)
    }
}
