import Foundation

final class StorageSubscriptionObserver<T: Decodable, V: Equatable>: Observable<V?> {
    let subscription: CallbackStorageSubscription<T>

    init(subscription: CallbackStorageSubscription<T>) {
        self.subscription = subscription

        super.init(state: nil)
    }
}

final class BatchStorageSubscriptionObserver<T: JSONListConvertible, V: Equatable>: Observable<V?> {
    let subscription: CallbackBatchStorageSubscription<T>

    init(subscription: CallbackBatchStorageSubscription<T>) {
        self.subscription = subscription

        super.init(state: nil)
    }
}
