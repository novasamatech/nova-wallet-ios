import Foundation
import Operation_iOS

protocol PriceLocalStorageSubscriber: LocalStorageProviderObserving where Self: AnyObject {
    var priceLocalSubscriptionFactory: PriceProviderFactoryProtocol { get }

    var priceLocalSubscriptionHandler: PriceLocalSubscriptionHandler { get }

    func subscribeToPrice(
        for priceId: AssetModel.PriceId,
        currency: Currency,
        options: StreamableProviderObserverOptions
    ) -> StreamableProvider<PriceData>

    func subscribeAllPrices(
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

    func subscribeAllPrices(
        currency: Currency
    ) -> StreamableProvider<PriceData> {
        let options = StreamableProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false,
            initialSize: 0,
            refreshWhenEmpty: true
        )

        return subscribeAllPrices(currency: currency, options: options)
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

        addStreamableProviderObserver(
            for: priceProvider,
            updateClosure: { [weak self] (changes: [DataProviderChange<PriceData>]) in
                guard let self else {
                    return
                }

                let finalValue = changes.reduceToLastChange()
                priceLocalSubscriptionHandler.handlePrice(result: .success(finalValue), priceId: priceId)
            }, failureClosure: { [weak self] (error: Error) in
                guard let self else {
                    return
                }

                priceLocalSubscriptionHandler.handlePrice(result: .failure(error), priceId: priceId)
            },
            options: options
        )

        return priceProvider
    }

    func subscribeAllPrices(
        currency: Currency,
        options: StreamableProviderObserverOptions
    ) -> StreamableProvider<PriceData> {
        let provider = priceLocalSubscriptionFactory.getAllPricesStreamableProvider(
            currency: currency
        )

        addStreamableProviderObserver(
            for: provider,
            updateClosure: { [weak self] changes in
                self?.priceLocalSubscriptionHandler.handleAllPrices(result: .success(changes))
            },
            failureClosure: { [weak self] error in
                self?.priceLocalSubscriptionHandler.handleAllPrices(
                    result: .failure(error)
                )
            },
            options: options
        )

        return provider
    }

    func subscribeToPriceHistory(
        for priceId: AssetModel.PriceId,
        currency: Currency,
        options: DataProviderObserverOptions
    ) -> AnySingleValueProvider<PriceHistory> {
        let provider = priceLocalSubscriptionFactory.getPriceHistoryProvider(for: priceId, currency: currency)

        let updateClosure = { [weak self] (changes: [DataProviderChange<PriceHistory>]) in
            guard let self else {
                return
            }

            let finalValue = changes.reduceToLastChange()

            priceLocalSubscriptionHandler.handlePriceHistory(
                result: .success(finalValue),
                priceId: priceId
            )
        }

        let failureClosure = { [weak self] (error: Error) in
            guard let self else {
                return
            }

            priceLocalSubscriptionHandler.handlePriceHistory(result: .failure(error), priceId: priceId)
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
