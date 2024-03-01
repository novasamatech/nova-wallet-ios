import Foundation
import RobinHood
import SoraKeystore
import BigInt
import SoraFoundation

final class TransferHandler: CommonHandler, PushNotificationHandler {
    let operationQueue = OperationQueue()
    let callStore = CancellableCallStore()
    let chainId: ChainModel.Id
    let payload: NotificationTransferPayload
    let type: TransferType
    
    init(chainId: ChainModel.Id,
         payload: NotificationTransferPayload,
         type: TransferType) {
        self.chainId = chainId
        self.payload = payload
        self.type = type
    }
    
    func handle(callbackQueue: DispatchQueue?,
                completion: @escaping (NotificationContentResult?) -> Void) {
        let settingsOperation = settingsRepository.fetchAllOperation(with: .init())
        let chainOperation = chainsRepository.fetchAllOperation(with: .init())
        
        let contentWrapper: CompoundOperationWrapper<NotificationContentResult?> = OperationCombiningService.compoundWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)) {
                let settings = try settingsOperation.extractNoCancellableResultData().first
                let chains = try chainOperation.extractNoCancellableResultData()
                guard let chain = chains.first(where: { $0.chainId == self.chainId }),
                      let asset = self.mapHistoryAssetId(self.payload.assetId, chain: chain) else {
                    return nil
                }
                
                let priceOperation: BaseOperation<[PriceData]>
                if let priceId = asset.priceId, let currency = self.currencyManager()?.selectedCurrency {
                    priceOperation = self.priceRepository(for: priceId, currencyId: currency.id).fetchAllOperation(with: .init())
                } else {
                    priceOperation = .createWithResult([])
                }
                priceOperation.addDependency(chainOperation)
                
                let mapOperaion = ClosureOperation {
                    let price = try priceOperation.extractNoCancellableResultData().first
                    return self.updatingContent(wallets: settings?.wallets ?? [],
                                                chain: chain,
                                                asset: asset,
                                                price: price,
                                                payload: self.payload)
                }
                
                mapOperaion.addDependency(priceOperation)
                
                return .init(targetOperation: mapOperaion, dependencies: [priceOperation])
            }
        
        contentWrapper.addDependency(operations: [settingsOperation, chainOperation])
        let wrapper = contentWrapper.insertingHead(operations: [settingsOperation, chainOperation])
        
        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: callbackQueue) { result in
                switch result {
                case .success(let content):
                    completion(content)
                case .failure:
                    completion(nil)
                }
            }
    }
    
    private func mapHistoryAssetId(_ assetId: String, chain: ChainModel) -> AssetModel? {
        if assetId == SubqueryHistoryElement.nativeFeeAssetId {
            return chain.utilityAsset()
        } else {
            return chain.asset(byHistoryAssetId: assetId)
        }
    }
    
    private func updatingContent(wallets: [Web3AlertWallet],
                                 chain: ChainModel,
                                 asset: AssetModel,
                                 price: PriceData?,
                                 payload: NotificationTransferPayload) -> NotificationContentResult {
        let walletString: String
        if wallets.count > 1 {
            //TODO: after adding metaId in settings
            walletString = "[]"
        } else {
            walletString = ""
        }
        let title = [type.title, walletString].joined(separator: " ")
        let balance = balanceViewModel(asset: asset, amount: payload.amount, priceData: price)
        let subtitle = type.subtitle(
            amount: balance?.amount ?? "",
            price: balance?.price,
            chainName: chain.name,
            address: type.address(from: payload)
        )
        
        return .init(title: title, subtitle: subtitle)
    }
    
    private func balanceViewModel(asset: AssetModel, amount: BigUInt, priceData: PriceData?) -> BalanceViewModelProtocol? {
        guard let currencyManager = currencyManager() else {
            return nil
        }
        let decimalAmount = amount.decimal(precision: asset.precision)
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let factory = BalanceViewModelFactory(targetAssetInfo: asset.displayInfo,
                                              priceAssetInfoFactory: priceAssetInfoFactory)
        return factory.balanceFromPrice(decimalAmount, priceData: priceData).value(for: LocalizationManager.shared.selectedLocale)
    }
    
    private func priceRepository(for priceId: String, currencyId: Int) -> CoreDataRepository<PriceData, CDPrice> {
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
    
    private func currencyManager() -> CurrencyManagerProtocol? {
        try? CurrencyManager(currencyRepository: CurrencyRepository(),
                             settingsManager: SettingsManager.shared,
                             queue: operationQueue)
    }
}
