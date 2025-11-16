import Foundation
import Operation_iOS

protocol GiftsLocalStorageSubscriber: AnyObject {
    var giftsLocalSubscriptionFactory: GiftsLocalSubscriptionFactoryProtocol { get }

    var giftsLocalSubscriptionHandler: GiftsLocalSubscriptionHandler { get }

    func subscribeAllGifts(for metaId: MetaAccountModel.Id?) -> StreamableProvider<GiftModel>
}

extension GiftsLocalStorageSubscriber {
    func subscribeAllGifts(for metaId: MetaAccountModel.Id?) -> StreamableProvider<GiftModel> {
        let provider = giftsLocalSubscriptionFactory.getAllGiftsProvider(for: metaId)

        let updateClosure = { [weak self] (changes: [DataProviderChange<GiftModel>]) in
            self?.giftsLocalSubscriptionHandler.handleAllGifts(result: .success(changes))
            return
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.giftsLocalSubscriptionHandler.handleAllGifts(result: .failure(error))
            return
        }

        let options = StreamableProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false,
            initialSize: 0,
            refreshWhenEmpty: true
        )

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

extension GiftsLocalStorageSubscriber where Self: GiftsLocalSubscriptionHandler {
    var giftsLocalSubscriptionHandler: GiftsLocalSubscriptionHandler { self }
}
