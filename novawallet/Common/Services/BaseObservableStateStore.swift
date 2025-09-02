import Foundation

protocol BaseObservableStateStoreProtocol {
    associatedtype RemoteState: Equatable

    func add(
        observer: AnyObject,
        sendStateOnSubscription: Bool,
        queue: DispatchQueue?,
        closure: @escaping Observable<RemoteState?>.StateChangeClosure
    )
    func remove(observer: AnyObject)
    func reset()
}

class BaseObservableStateStore<T: Equatable> {
    typealias RemoteState = T

    var stateObservable: Observable<T?> = .init(state: nil)
    let logger: LoggerProtocol
    let mutex = NSLock()

    init(logger: LoggerProtocol) {
        self.logger = logger
    }
}

extension BaseObservableStateStore: BaseObservableStateStoreProtocol {
    func add(
        observer: AnyObject,
        sendStateOnSubscription: Bool,
        queue: DispatchQueue?,
        closure: @escaping Observable<T?>.StateChangeClosure
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        stateObservable.addObserver(
            with: observer,
            sendStateOnSubscription: sendStateOnSubscription,
            queue: queue,
            closure: closure
        )
    }

    func add(
        observer: AnyObject,
        queue: DispatchQueue?,
        closure: @escaping Observable<T?>.StateChangeClosure
    ) {
        add(
            observer: observer,
            sendStateOnSubscription: true,
            queue: queue,
            closure: closure
        )
    }

    func remove(observer: AnyObject) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        stateObservable.removeObserver(by: observer)
    }

    func reset() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        stateObservable = .init(state: nil)
    }
}
