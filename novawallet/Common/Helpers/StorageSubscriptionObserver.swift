import Foundation

final class StorageSubscriptionObserver<T: Decodable, V: Equatable>: Observable<V?> {
    let subscription: CallbackStorageSubscription<T>

    init(subscription: CallbackStorageSubscription<T>) {
        self.subscription = subscription

        super.init(state: nil)
    }
}
