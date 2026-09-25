import Foundation
import Operation_iOS

struct BittensorApiPages<T> {
    let pages: [BittensorApiResult<T>]
    let hasMorePages: Bool
}

enum BittensorApiPagination {
    static func createPagesWrapper<T>(
        maxPages: Int,
        operationQueue: OperationQueue,
        nextPage: @escaping (T) -> Int?,
        pageWrapper: @escaping (Int) -> CompoundOperationWrapper<BittensorApiResult<T>>
    ) -> CompoundOperationWrapper<BittensorApiPages<T>> {
        let fetch = BittensorApiPageFetch(
            maxPages: max(1, maxPages),
            operationQueue: operationQueue,
            nextPage: nextPage,
            pageWrapper: pageWrapper
        )

        let operation = AsyncClosureOperation<BittensorApiPages<T>>(
            operationClosure: { completion in
                fetch.start(completion: completion)
            },
            cancelationClosure: {
                fetch.cancel()
            }
        )

        return CompoundOperationWrapper(targetOperation: operation)
    }
}

private final class BittensorApiPageFetch<T> {
    typealias Completion = (Result<BittensorApiPages<T>, Error>) -> Void

    private let maxPages: Int
    private let operationQueue: OperationQueue
    private let nextPage: (T) -> Int?
    private let pageWrapper: (Int) -> CompoundOperationWrapper<BittensorApiResult<T>>
    private let mutex = NSLock()

    private var pages: [BittensorApiResult<T>] = []
    private var completion: Completion?
    private var currentWrapper: CompoundOperationWrapper<BittensorApiResult<T>>?
    private var isCancelled = false

    init(
        maxPages: Int,
        operationQueue: OperationQueue,
        nextPage: @escaping (T) -> Int?,
        pageWrapper: @escaping (Int) -> CompoundOperationWrapper<BittensorApiResult<T>>
    ) {
        self.maxPages = maxPages
        self.operationQueue = operationQueue
        self.nextPage = nextPage
        self.pageWrapper = pageWrapper
    }

    func start(completion: @escaping Completion) {
        mutex.lock()

        self.completion = completion

        mutex.unlock()

        fetch(page: 1)
    }

    func cancel() {
        mutex.lock()

        isCancelled = true
        completion = nil

        let wrapper = currentWrapper
        currentWrapper = nil

        mutex.unlock()

        wrapper?.cancel()
    }

    private func fetch(page: Int) {
        let wrapper = pageWrapper(page)

        mutex.lock()

        guard !isCancelled else {
            mutex.unlock()

            return
        }

        currentWrapper = wrapper

        mutex.unlock()

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: nil
        ) { result in
            self.handle(result, page: page)
        }
    }

    private func handle(_ result: Result<BittensorApiResult<T>, Error>, page: Int) {
        mutex.lock()

        guard !isCancelled, let completion else {
            mutex.unlock()

            return
        }

        let pageResult: BittensorApiResult<T>

        switch result {
        case let .success(value):
            pageResult = value
        case let .failure(error):
            self.completion = nil
            mutex.unlock()

            completion(.failure(error))

            return
        }

        pages.append(pageResult)

        let next = nextPage(pageResult.value)

        if let next, next > page, pages.count < maxPages {
            mutex.unlock()

            fetch(page: next)

            return
        }

        let outcome = BittensorApiPages(pages: pages, hasMorePages: next != nil)
        self.completion = nil

        mutex.unlock()

        completion(.success(outcome))
    }
}
