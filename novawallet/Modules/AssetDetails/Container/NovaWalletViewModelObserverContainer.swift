import UIKit_iOS

public struct NovaWalletViewModelObserverWrapper<Observer> where Observer: AnyObject {
    weak var observer: Observer?

    init(observer: Observer) {
        self.observer = observer
    }
}

public final class NovaWalletViewModelObserverContainer<Observer> where Observer: AnyObject {
    private(set) var observers: [NovaWalletViewModelObserverWrapper<Observer>] = []

    public init() {}

    public func add(observer: Observer) {
        observers = observers.filter { $0.observer != nil }

        guard !observers.contains(where: { $0.observer === observer }) else {
            return
        }

        observers.append(NovaWalletViewModelObserverWrapper(observer: observer))
    }

    public func remove(observer: Observer) {
        observers = observers.filter { $0.observer != nil && $0.observer !== observer }
    }
}
