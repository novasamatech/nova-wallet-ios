import Foundation

protocol WalletDelayedExecutionProviding {
    func setup()
    func throttle()

    func subscribeDelayedExecVerifier(
        _ target: AnyObject,
        notifyingIn queue: DispatchQueue,
        onChange: @escaping (WalletDelayedExecVerifing) -> Void
    )

    func unsubscribe(_ target: AnyObject)

    func getCurrentState() -> WalletDelayedExecVerifing
}

final class WalletDelayedExecutionProvider {
    let repository: WalletDelayedExecutionRepositoryProtocol
    let workQueue: DispatchQueue
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private let mutex = NSLock()
    private var isActive: Bool = false

    private let callStore = CancellableCallStore()

    private var observableState: Observable<NotEqualWrapper<WalletDelayedExecVerifing>>

    init(
        selectedWallet: MetaAccountModel,
        repository: WalletDelayedExecutionRepositoryProtocol,
        operationQueue: OperationQueue,
        workQueue: DispatchQueue = .global(),
        logger: LoggerProtocol
    ) {
        self.repository = repository
        self.operationQueue = operationQueue
        self.workQueue = workQueue
        self.logger = logger

        observableState = .init(
            state: .init(
                value: NotDelegatedCallDelayedExecVerifier(
                    selectedWallet: selectedWallet
                )
            )
        )
    }
}

private extension WalletDelayedExecutionProvider {
    func fetchAndSetupVerifier() {
        let wrapper = repository.createVerifier()

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: workQueue,
            mutex: mutex
        ) { [weak self] result in
            switch result {
            case let .success(verifier):
                self?.observableState.state = .init(value: verifier)
            case let .failure(error):
                self?.logger.error("Unexpected error: \(error)")
            }
        }
    }
}

extension WalletDelayedExecutionProvider: WalletDelayedExecutionProviding {
    func setup() {
        mutex.lock()

        defer {
            self.mutex.unlock()
        }

        guard !isActive else {
            return
        }

        isActive = true

        fetchAndSetupVerifier()
    }

    func throttle() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard isActive else {
            return
        }

        isActive = false

        callStore.cancel()
    }

    func subscribeDelayedExecVerifier(
        _ target: AnyObject,
        notifyingIn queue: DispatchQueue,
        onChange: @escaping (WalletDelayedExecVerifing) -> Void
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        observableState.addObserver(
            with: target,
            sendStateOnSubscription: true,
            queue: queue
        ) { _, newState in
            onChange(newState.value)
        }
    }

    func unsubscribe(_ target: AnyObject) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        observableState.removeObserver(by: target)
    }

    func getCurrentState() -> WalletDelayedExecVerifing {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return observableState.state.value
    }
}
