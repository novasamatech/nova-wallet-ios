import Foundation
import Operation_iOS

final class SubtensorCostBasisWalk {
    typealias Completion = (Result<SubtensorCostBasisLedger, Error>) -> Void

    struct Settings {
        static let standard = Settings(requestSpacing: 12, retryDelay: 20, maxPages: 10)

        let requestSpacing: TimeInterval
        let retryDelay: TimeInterval
        let maxPages: Int
    }

    let accountSubject: AccountAddress
    let apiOperationFactory: BittensorApiOperationFactoryProtocol
    let operationQueue: OperationQueue
    let settings: Settings
    let timeProvider: () -> TimeInterval
    let logger: LoggerProtocol

    private let mutex = NSLock()
    private var completion: Completion?
    private var currentCall: CancellableCall?
    private var isCancelled = false
    private var operations: [BittensorApi.Operation] = []
    private var nextPage = 1
    private var hasRetriedPage = false
    private var nextRequestAt: TimeInterval?

    init(
        accountSubject: AccountAddress,
        apiOperationFactory: BittensorApiOperationFactoryProtocol,
        operationQueue: OperationQueue,
        settings: Settings,
        timeProvider: @escaping () -> TimeInterval,
        logger: LoggerProtocol
    ) {
        self.accountSubject = accountSubject
        self.apiOperationFactory = apiOperationFactory
        self.operationQueue = operationQueue
        self.settings = settings
        self.timeProvider = timeProvider
        self.logger = logger
    }

    func start(completion: @escaping Completion) {
        mutex.lock()

        self.completion = completion

        mutex.unlock()

        advance()
    }
}

extension SubtensorCostBasisWalk: CancellableCall {
    func cancel() {
        mutex.lock()

        isCancelled = true
        completion = nil

        let call = currentCall
        currentCall = nil

        mutex.unlock()

        call?.cancel()
    }
}

private extension SubtensorCostBasisWalk {
    typealias Page = BittensorApiResult<BittensorApi.OperationCollection>

    enum Step {
        case request
        case collected([BittensorApi.Operation], isHistoryComplete: Bool)
        case failed(Error)
    }

    func advance() {
        mutex.lock()

        guard !isCancelled else {
            mutex.unlock()

            return
        }

        let page = nextPage
        let delay = (nextRequestAt ?? 0) - timeProvider()

        mutex.unlock()

        guard delay > 0 else {
            request(page: page)

            return
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.request(page: page)
        }
    }

    func request(page: Int) {
        mutex.lock()

        guard !isCancelled else {
            mutex.unlock()

            return
        }

        let wrapper = apiOperationFactory.createOperationsWrapper(accountSubject: accountSubject, page: page)
        currentCall = wrapper

        mutex.unlock()

        let requestedAt = timeProvider()

        execute(wrapper: wrapper, inOperationQueue: operationQueue, runningCallbackIn: nil) { [weak self] result in
            self?.handle(result, page: page, requestedAt: requestedAt)
        }
    }

    func handle(_ result: Result<Page, Error>, page: Int, requestedAt: TimeInterval) {
        mutex.lock()

        guard !isCancelled else {
            mutex.unlock()

            return
        }

        let step = nextStep(after: result, page: page, requestedAt: requestedAt)

        mutex.unlock()

        switch step {
        case .request:
            advance()
        case let .collected(operations, isHistoryComplete):
            let ledger = SubtensorCostBasisLedger(operations: operations, isHistoryComplete: isHistoryComplete)

            finish(with: .success(ledger))
        case let .failed(error):
            finish(with: .failure(error))
        }
    }

    func nextStep(after result: Result<Page, Error>, page: Int, requestedAt: TimeInterval) -> Step {
        switch Self.unexpired(result) {
        case let .success(response):
            return accept(response, page: page, requestedAt: requestedAt)
        case let .failure(error) where Self.isTransient(error) && !hasRetriedPage:
            logger.warning("Subtensor cost basis page \(page) is retried in \(settings.retryDelay) s after: \(error)")

            hasRetriedPage = true
            nextRequestAt = timeProvider() + settings.retryDelay

            return .request
        case let .failure(error):
            return .failed(error)
        }
    }

    func accept(_ response: Page, page: Int, requestedAt: TimeInterval) -> Step {
        let pageInfo = response.value.pageInfo

        guard pageInfo.page == page else {
            return .failed(
                BittensorApiError.contractViolation(
                    detail: "POST /operations/search: page \(page) answered as page \(pageInfo.page)",
                    requestId: response.requestId
                )
            )
        }

        operations.append(contentsOf: response.value.items)
        hasRetriedPage = false
        pace(afterReceivingAt: response.receivedAt, requestedAt: requestedAt)

        guard let followingPage = pageInfo.nextPage else {
            return .collected(operations, isHistoryComplete: true)
        }

        guard page < settings.maxPages else {
            return .collected(operations, isHistoryComplete: false)
        }

        nextPage = followingPage

        return .request
    }

    func pace(afterReceivingAt receivedAt: TimeInterval, requestedAt: TimeInterval) {
        guard receivedAt >= requestedAt else {
            return
        }

        nextRequestAt = timeProvider() + settings.requestSpacing
    }

    func finish(with result: Result<SubtensorCostBasisLedger, Error>) {
        mutex.lock()

        let completion = self.completion

        self.completion = nil
        currentCall = nil

        mutex.unlock()

        completion?(result)
    }

    static func unexpired(_ result: Result<Page, Error>) -> Result<Page, Error> {
        guard case let .success(page) = result, page.isFromExpiredCache else {
            return result
        }

        return .failure(SubtensorCostBasisError.expiredHistoryPage)
    }

    static func isTransient(_ error: Error) -> Bool {
        if let costBasisError = error as? SubtensorCostBasisError {
            return costBasisError == .expiredHistoryPage
        }

        guard let apiError = error as? BittensorApiError else {
            return false
        }

        switch apiError {
        case .upstreamUnavailable, .upstreamInvalidResponse, .attestationUnavailable, .transport:
            return true
        case let .server(statusCode, _, _):
            return (500 ... 599).contains(statusCode)
        case .unsupportedDevice, .configuration, .attestationRejected, .attestationBackoff, .attestationFailure,
             .routeNotPublished, .invalidRequest, .datasetUnavailable, .rateLimited, .contractViolation:
            return false
        }
    }
}
