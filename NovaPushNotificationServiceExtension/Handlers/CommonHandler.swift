import RobinHood
import SoraFoundation
import SoraKeystore
import BigInt

class CommonHandler {
    let userStorageFacade: StorageFacadeProtocol
    let substrateStorageFacade: StorageFacadeProtocol
    var locale: Locale {
        LocalizationManager.shared.selectedLocale
    }

    lazy var settingsRepository: AnyDataProviderRepository<LocalPushSettings> = createSettingsRepository()
    lazy var chainsRepository: AnyDataProviderRepository<ChainModel> = createChainsRepository()
    let settingsManager: SettingsManagerProtocol

    init(
        userStorageFacade: StorageFacadeProtocol = UserDataStorageFacade.shared,
        substrateStorageFacade: StorageFacadeProtocol = SubstrateDataStorageFacade.shared,
        settingsManager: SettingsManagerProtocol = SharedSettingsManager() ?? SettingsManager.shared
    ) {
        self.userStorageFacade = userStorageFacade
        self.substrateStorageFacade = substrateStorageFacade
        self.settingsManager = settingsManager
    }

    func createSettingsRepository() -> AnyDataProviderRepository<LocalPushSettings> {
        let pushSettings = NSPredicate(
            format: "%K == %@",

            #keyPath(CDUserSingleValue.identifier),
            LocalPushSettings.getIdentifier()
        )

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

extension CommonHandler {
    func balanceViewModel(
        asset: AssetModel,
        amount: BigUInt,
        priceData: PriceData?,
        workingQueue: OperationQueue
    ) -> BalanceViewModelProtocol? {
        guard let currencyManager = currencyManager(operationQueue: workingQueue) else {
            return nil
        }
        let decimalAmount = amount.decimal(precision: asset.precision)
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let factory = BalanceViewModelFactory(
            targetAssetInfo: asset.displayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )
        return factory.balanceFromPrice(decimalAmount, priceData: priceData).value(for: locale)
    }

    func priceRepository(for priceId: String, currencyId: Int) -> CoreDataRepository<PriceData, CDPrice> {
        let mapper = PriceDataMapper()
        let identifier = PriceData.createIdentifier(for: priceId, currencyId: currencyId)
        let filter = NSPredicate(format: "%K == %@", #keyPath(CDPrice.identifier), identifier)

        let repository: CoreDataRepository<PriceData, CDPrice> = substrateStorageFacade.createRepository(
            filter: filter,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        return repository
    }

    func currencyManager(operationQueue: OperationQueue) -> CurrencyManagerProtocol? {
        try? CurrencyManager(
            currencyRepository: CurrencyRepository(),
            settingsManager: SharedSettingsManager() ?? SettingsManager.shared,
            queue: operationQueue
        )
    }
}
