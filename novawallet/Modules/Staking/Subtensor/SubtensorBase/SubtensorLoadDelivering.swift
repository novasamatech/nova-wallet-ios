import Foundation
import Operation_iOS

protocol SubtensorLoadDelivering: AnyObject {
    var operationQueue: OperationQueue { get }
    var logger: LoggerProtocol { get }
}

extension SubtensorLoadDelivering {
    func load<T>(
        _ wrapper: CompoundOperationWrapper<T>,
        in callStore: CancellableCallStore,
        label: String,
        deliver: @escaping (T?) -> Void
    ) {
        load(wrapper, in: callStore, label: label, deliver: { deliver($0) }, fail: { deliver(nil) })
    }

    func load<T>(
        _ wrapper: CompoundOperationWrapper<T>,
        in callStore: CancellableCallStore,
        label: String,
        deliver: @escaping (T) -> Void,
        fail: @escaping () -> Void
    ) {
        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(value):
                deliver(value)
            case let .failure(error):
                self?.logger.warning("Subtensor \(label) unavailable: \(error)")
                fail()
            }
        }
    }

    func load<T>(
        _ wrapper: CompoundOperationWrapper<T>,
        cached: @escaping () -> T?,
        in callStore: CancellableCallStore,
        label: String,
        deliver: @escaping (T?) -> Void,
        onRefetchFailure: (() -> Void)? = nil
    ) {
        loadCached(cached, in: callStore, then: { [weak self] value in
            if let value {
                deliver(value)
            }

            self?.load(wrapper, in: callStore, label: label, deliver: { deliver($0) }, fail: {
                if value == nil {
                    deliver(nil)
                } else {
                    onRefetchFailure?()
                }
            })
        })
    }

    func loadCached<T>(
        _ cached: @escaping () -> T,
        in callStore: CancellableCallStore,
        then deliver: @escaping (T) -> Void
    ) {
        executeCancellable(
            wrapper: CompoundOperationWrapper(targetOperation: ClosureOperation(closure: cached)),
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: .main
        ) { result in
            if case let .success(value) = result {
                deliver(value)
            }
        }
    }
}
