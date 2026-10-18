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
}
