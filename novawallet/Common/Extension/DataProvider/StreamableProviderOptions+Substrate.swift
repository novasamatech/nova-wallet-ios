import Foundation
import Operation_iOS

extension StreamableProviderObserverOptions {
    static func substrateSource(for initSize: Int = 0) -> StreamableProviderObserverOptions {
        StreamableProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false,
            initialSize: initSize,
            refreshWhenEmpty: false
        )
    }

    static func allNonblocking() -> StreamableProviderObserverOptions {
        StreamableProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false,
            initialSize: 0,
            refreshWhenEmpty: true
        )
    }
}
