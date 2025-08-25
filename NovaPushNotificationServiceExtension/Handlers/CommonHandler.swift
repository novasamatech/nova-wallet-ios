import Operation_iOS
import Foundation_iOS
import Keystore_iOS
import BigInt

class CommonHandler {
    let userStorageFacade: StorageFacadeProtocol
    let substrateStorageFacade: StorageFacadeProtocol
    var locale: Locale {
        LocalizationManager.shared.selectedLocale
    }

    lazy var settingsRepository: AnyDataProviderRepository<Web3Alert.LocalSettings> = createSettingsRepository()
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

    func createSettingsRepository() -> AnyDataProviderRepository<Web3Alert.LocalSettings> {
        let pushSettings = NSPredicate(
            format: "%K == %@",
            #keyPath(CDUserSingleValue.identifier),
            Web3Alert.LocalSettings.getIdentifier()
        )

        let repository: CoreDataRepository<Web3Alert.LocalSettings, CDUserSingleValue> =
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

    func search(chainId: ChainModel.Id, in chains: [ChainModel]) -> ChainModel? {
        chains.first(where: { chain in
            let remoteChainId = Web3Alert.createRemoteChainId(from: chain.chainId)
            return remoteChainId == chainId
        })
    }
}

extension CommonHandler {
    func balanceViewModel(
        asset: AssetModel,
        amount: String,
        priceData: PriceData?,
        workingQueue: OperationQueue
    ) -> BalanceViewModelProtocol? {
        guard
            let currencyManager = currencyManager(operationQueue: workingQueue),
            let amountInPlank = BigUInt(amount) else {
            return nil
        }
        let decimalAmount = amountInPlank.decimal(precision: asset.precision)
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let factory = PrimitiveBalanceViewModelFactory(
            targetAssetInfo: asset.displayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory,
            formatterFactory: AssetBalanceFormatterFactory()
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

    func targetWallet(
        for address: AccountAddress?,
        chain: ChainModel,
        metaAccounts: [MetaAccountModel]
    ) -> MetaAccountModel? {
        guard let accountId = try? address?.toChainAccountIdOrSubstrateGeneric(using: chain.chainFormat) else {
            return nil
        }

        let chainRequest = chain.accountRequest()

        return metaAccounts
            .filter { $0.fetchByAccountId(accountId, request: chainRequest) != nil }
            .sorted { $0.type.signingDelegateOrder < $1.type.signingDelegateOrder }
            .first
    }

    func walletsRepository() -> AnyDataProviderRepository<MetaAccountModel> {
        let mapper = MetaAccountMapper()

        let repository = userStorageFacade.createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        return AnyDataProviderRepository(repository)
    }
}
