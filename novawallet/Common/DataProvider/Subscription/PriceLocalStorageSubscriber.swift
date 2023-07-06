import Foundation
import RobinHood

protocol PriceLocalStorageSubscriber where Self: AnyObject {
    var priceLocalSubscriptionFactory: PriceProviderFactoryProtocol { get }

    var priceLocalSubscriptionHandler: PriceLocalSubscriptionHandler { get }

    func subscribeToPrice(
        for priceId: AssetModel.PriceId,
        currency: Currency,
        options: StreamableProviderObserverOptions
    ) -> StreamableProvider<PriceData>

    func subscribeToPriceHistory(
        for priceId: AssetModel.PriceId,
        currency: Currency,
        options: DataProviderObserverOptions
    ) -> AnySingleValueProvider<PriceHistory>
}

extension PriceLocalStorageSubscriber {
    func subscribeToPrice(
        for priceId: AssetModel.PriceId,
        currency: Currency
    ) -> StreamableProvider<PriceData> {
        let options = StreamableProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false,
            initialSize: 0,
            refreshWhenEmpty: true
        )

        return subscribeToPrice(for: priceId, currency: currency, options: options)
    }

    func subscribeToPriceHistory(
        for priceId: AssetModel.PriceId,
        currency: Currency
    ) -> AnySingleValueProvider<PriceHistory> {
        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        return subscribeToPriceHistory(for: priceId, currency: currency, options: options)
    }
}

extension PriceLocalStorageSubscriber {
    func subscribeToPrice(
        for priceId: AssetModel.PriceId,
        currency: Currency,
        options: StreamableProviderObserverOptions
    ) -> StreamableProvider<PriceData> {
        let priceProvider = priceLocalSubscriptionFactory.getPriceStreamableProvider(
            for: priceId,
            currency: currency
        )

        let updateClosure = { [weak self] (changes: [DataProviderChange<PriceData>]) in
            let finalValue = changes.reduceToLastChange()
            self?.priceLocalSubscriptionHandler.handlePrice(result: .success(finalValue), priceId: priceId)
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.priceLocalSubscriptionHandler.handlePrice(result: .failure(error), priceId: priceId)
            return
        }

        priceProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return priceProvider
    }

    func subscribeToPriceHistory(
        for priceId: AssetModel.PriceId,
        currency: Currency,
        options: DataProviderObserverOptions
    ) -> AnySingleValueProvider<PriceHistory> {
        let provider = priceLocalSubscriptionFactory.getPriceHistoryProvider(for: priceId, currency: currency)

        let updateClosure = { [weak self] (changes: [DataProviderChange<PriceHistory>]) in
            let finalValue = changes.reduceToLastChange()
            self?.priceLocalSubscriptionHandler.handlePriceHistory(
                result: .success(finalValue),
                priceId: priceId
            )
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.priceLocalSubscriptionHandler.handlePriceHistory(result: .failure(error), priceId: priceId)
            return
        }

        provider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return provider
    }
}

extension PriceLocalStorageSubscriber where Self: PriceLocalSubscriptionHandler {
    var priceLocalSubscriptionHandler: PriceLocalSubscriptionHandler { self }
}
