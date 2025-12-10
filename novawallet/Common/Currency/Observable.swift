import Foundation
import Operation_iOS

public protocol ObservableProtocol: AnyObject {
    associatedtype State
    typealias StateChangeClosure = (State, State) -> Void

    var state: State { get set }

    func addObserver(
        with owner: AnyObject,
        queue: DispatchQueue?,
        closure: @escaping StateChangeClosure
    )

    func removeObserver(by owner: AnyObject)

    func hasObserver(_ owner: AnyObject) -> Bool
}

public class Observable<TState>: ObservableProtocol where TState: Equatable {
    public typealias State = TState
    public typealias VoidClosure = () -> Void

    public struct ObserverWrapper {
        public weak var owner: AnyObject?
        public let closure: (TState, TState) -> Void
        public let queue: DispatchQueue?
    }

    public private(set) var observers: [ObserverWrapper] = []

    public var state: TState {
        didSet {
            if oldValue != state {
                sideEffectOnChangeState?()
                notify(oldState: oldValue, newState: state)
            }
        }
    }

    public var sideEffectOnChangeState: VoidClosure?

    public init(state: TState) {
        self.state = state
    }

    public func addObserver(
        with owner: AnyObject,
        queue: DispatchQueue? = nil,
        closure: @escaping (TState, TState) -> Void
    ) {
        observers.append(ObserverWrapper(
            owner: owner,
            closure: closure,
            queue: queue
        ))

        observers = observers.filter { $0.owner !== nil }
    }

    public func removeObserver(by owner: AnyObject) {
        observers = observers.filter { $0.owner !== owner && $0.owner !== nil }
    }

    public func hasObserver(_ owner: AnyObject) -> Bool {
        observers.contains { $0.owner === owner }
    }

    private func notify(oldState: TState, newState: TState) {
        observers = observers.filter { $0.owner !== nil }

        observers.forEach { wrapper in
            if wrapper.owner != nil {
                dispatchInQueueWhenPossible(wrapper.queue) {
                    wrapper.closure(oldState, newState)
                }
            }
        }
    }
}

extension Observable where TState: Equatable {
    func addObserver(
        with owner: AnyObject,
        closure: @escaping StateChangeClosure
    ) {
        addObserver(with: owner, sendStateOnSubscription: false, closure: closure)
    }

    func addObserver(
        with owner: AnyObject,
        sendStateOnSubscription: Bool,
        queue: DispatchQueue? = nil,
        closure: @escaping StateChangeClosure
    ) {
        addObserver(with: owner, queue: queue, closure: closure)

        if sendStateOnSubscription {
            let currentState = state
            dispatchInQueueWhenPossible(queue) {
                closure(currentState, currentState)
            }
        }
    }
}
