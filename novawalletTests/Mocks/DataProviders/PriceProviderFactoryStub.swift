import Foundation
@testable import novawallet
import Operation_iOS

final class PriceProviderFactoryStub: PriceProviderFactoryProtocol {
    let priceData: PriceData?
    let storageFacade: StorageFacadeProtocol
    let operationQueue: OperationQueue

    init(
        priceData: PriceData? = nil,
        storageFacade: StorageFacadeProtocol = SubstrateStorageTestFacade(),
        operationQueue: OperationQueue = OperationQueue()
    ) {
        self.priceData = priceData
        self.storageFacade = storageFacade
        self.operationQueue = operationQueue
    }

    func getPriceStreamableProvider(
        for _: AssetModel.PriceId,
        currency _: Currency
    ) -> StreamableProvider<PriceData> {
        createProvider(from: createRepository())
    }

    func getAllPricesStreamableProvider(currency _: Currency) -> StreamableProvider<PriceData> {
        createProvider(from: createRepository())
    }

    private func createRepository() -> AnyDataProviderRepository<PriceData> {
        let repository = storageFacade.createRepository(mapper: AnyCoreDataMapper(PriceDataMapper()))

        if let priceData = priceData {
            let operation = repository.saveOperation({
                [priceData]
            }, { [] })

            operationQueue.addOperations([operation], waitUntilFinished: true)
        }

        return AnyDataProviderRepository(repository)
    }

    private func createProvider(from repository: AnyDataProviderRepository<PriceData>) -> StreamableProvider<PriceData> {
        StreamableProvider(
            source: AnyStreamableSource(EmptyStreamableSource()),
            repository: repository,
            observable: AnyDataProviderRepositoryObservable(DataProviderObservableStub()),
            operationManager: OperationManager(operationQueue: operationQueue)
        )
    }

    func getPriceProvider(for _: AssetModel.PriceId, currency _: Currency) -> AnySingleValueProvider<PriceData> {
        let provider = SingleValueProviderStub(item: priceData)
        return AnySingleValueProvider(provider)
    }

    func getPriceListProvider(for _: [AssetModel.PriceId], currency _: Currency) -> AnySingleValueProvider<[PriceData]> {
        let priceList = priceData.map { [$0] } ?? []
        let provider = SingleValueProviderStub(item: priceList)
        return AnySingleValueProvider(provider)
    }

    func getPriceHistoryProvider(
        for _: AssetModel.PriceId,
        currency: Currency
    ) -> AnySingleValueProvider<PriceHistory> {
        let priceHistory = PriceHistory(currencyId: currency.id, items: [])
        let provider = SingleValueProviderStub(item: priceHistory)
        return AnySingleValueProvider(provider)
    }
}
