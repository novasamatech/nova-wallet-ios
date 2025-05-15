import Foundation
import Operation_iOS

protocol RaiseAuthProviding {
    func setup()
    func fetchAuthToken(_ forceRefresh: Bool) -> BaseOperation<RaiseAuthToken>
}

final class RaiseAuthProvider {
    struct PendingRequest {
        let resultClosure: (Result<RaiseAuthToken, Error>) -> Void
        let queue: DispatchQueue?
    }

    enum Snapshot {
        case ready
        case loading
    }

    let authFactory: RaiseAuthFactoryProtocol
    let authStore: RaiseAuthKeyStorageProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private var isLoadingToken: Bool = false
    private var pendingRequests: [UUID: PendingRequest] = [:]
    private let cancellableStore = CancellableCallStore()
    private var mutex = NSLock()

    init(
        authFactory: RaiseAuthFactoryProtocol,
        authStore: RaiseAuthKeyStorageProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.authFactory = authFactory
        self.authStore = authStore
        self.operationQueue = operationQueue
        self.logger = logger
    }

    private func loadToken() {
        let wrapper = authFactory.createAuthTokenRequest()

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: cancellableStore,
            runningCallbackIn: .global()
        ) { [weak self] result in
            self?.handleCompletion(result: result)
        }
    }

    private func refreshTokenIfNeeded() {
        guard
            let auth = authStore.fetchAuthToken(),
            !auth.isExpired,
            auth.expiringIn(timeInterval: TimeInterval.secondsInDay) else {
            return
        }

        isLoadingToken = true

        let operation = authFactory.createRefreshTokenRequest(for: auth.token)

        execute(
            operation: operation,
            inOperationQueue: operationQueue,
            backingCallIn: cancellableStore,
            runningCallbackIn: .global()
        ) { [weak self] result in
            self?.handleCompletion(result: result)
        }
    }

    private func handleCompletion(result: Result<RaiseAuthToken, Error>) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        isLoadingToken = false

        do {
            let token = try result.get()
            logger.debug("New token until: \(Date(timeIntervalSince1970: TimeInterval(token.expiresAt)))")

            try authStore.saveAuth(token: token)

            resolveRequests(for: .success(token))
        } catch {
            logger.debug("Failed to load token: \(error)")

            resolveRequests(for: .failure(error))
        }
    }

    private func resolveRequests(for result: Result<RaiseAuthToken, Error>) {
        guard !pendingRequests.isEmpty else {
            return
        }

        let requests = pendingRequests
        pendingRequests = [:]

        requests.forEach { deliver(tokenResult: result, to: $0.value) }
    }

    private func deliver(tokenResult: Result<RaiseAuthToken, Error>, to request: PendingRequest) {
        dispatchInQueueWhenPossible(request.queue) {
            request.resultClosure(tokenResult)
        }
    }

    private func fetchToken(
        assigning requestId: UUID,
        isForced: Bool,
        runCompletionIn queue: DispatchQueue?,
        executing closure: @escaping (Result<RaiseAuthToken, Error>) -> Void
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let request = PendingRequest(resultClosure: closure, queue: queue)

        let optToken = authStore.fetchAuthToken()

        if let token = optToken, !token.isExpired, !isForced {
            deliver(tokenResult: .success(token), to: request)
        } else {
            pendingRequests[requestId] = request

            if !isLoadingToken {
                isLoadingToken = true

                try? authStore.saveAuth(token: nil)

                loadToken()
            }
        }
    }

    private func cancelRequest(for requestId: UUID) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let maybePendingRequest = pendingRequests[requestId]
        pendingRequests[requestId] = nil

        if let pendingRequest = maybePendingRequest {
            deliver(tokenResult: .failure(BaseOperationError.parentOperationCancelled), to: pendingRequest)
        }
    }
}

extension RaiseAuthProvider: RaiseAuthProviding {
    func setup() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        refreshTokenIfNeeded()
    }

    func fetchAuthToken(_ forceRefresh: Bool) -> BaseOperation<RaiseAuthToken> {
        let requestId = UUID()

        return AsyncClosureOperation(
            operationClosure: { [weak self] responseClosure in
                if let strongSelf = self {
                    strongSelf.fetchToken(
                        assigning: requestId,
                        isForced: forceRefresh,
                        runCompletionIn: nil
                    ) { result in
                        responseClosure(result)
                    }
                } else {
                    responseClosure(.failure(RuntimeProviderError.providerUnavailable))
                }
            },
            cancelationClosure: { [weak self] in
                self?.cancelRequest(for: requestId)
            }
        )
    }
}
