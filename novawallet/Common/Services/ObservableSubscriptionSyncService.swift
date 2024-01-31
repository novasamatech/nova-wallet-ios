import Foundation

struct ObservableSubscriptionState {
    
}

class ObservableSubscriptionSyncService<TChange: BatchStorageSubscriptionResult>: ObservableSyncService {
    private var state: HydraDx.SwapRemoteState?
    private var subscription: CallbackBatchStorageSubscription<HydraDx.SwapRemoteStateChange>?
}
