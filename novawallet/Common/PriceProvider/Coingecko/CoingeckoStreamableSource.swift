import Foundation
import Operation_iOS
import Combine

final class CoingeckoStreamableSource: StreamableSourceProtocol {
    typealias Model = PriceData

    private let cancellableStore = CancellableCallStore()
    private var cancellable: AnyCancellable?
    private let priceIdsObservable: AnyPublisher<Set<AssetModel.PriceId>, Never>
    private var priceIds: Set<AssetModel.PriceId> = [] {
        willSet {
            guard newValue != priceIds,
                  cancellableStore.hasCall
            else {
                return
            }
            cancellableStore.cancel()
        }
        didSet {
            refresh(
                runningIn: queue,
                commitNotificationBlock: nil
            )
        }
    }

    private let queue = DispatchQueue(
        label: "io.novasama.coingeckostreamablesource.queue.\(UUID().uuidString)",
        qos: .utility
    )

    let currency: Currency
    let repository: AnyDataProviderRepository<PriceData>
    let operationQueue: OperationQueue

    init(
        priceIdsObservable: AnyPublisher<Set<AssetModel.PriceId>, Never>,
        currency: Currency,
        repository: AnyDataProviderRepository<PriceData>,
        operationQueue: OperationQueue
    ) {
        self.priceIdsObservable = priceIdsObservable
        self.currency = currency
        self.repository = repository
        self.operationQueue = operationQueue
        subscribe()
    }

    deinit {
        cancellableStore.cancel()
    }

    func fetchHistory(runningIn queue: DispatchQueue?, commitNotificationBlock: ((Result<Int, Error>?) -> Void)?) {
        guard let closure = commitNotificationBlock else {
            return
        }

        let result: Result<Int, Error> = Result.success(0)

        if let queue {
            queue.async {
                closure(result)
            }
        } else {
            closure(result)
        }
    }

    func refresh(
        runningIn queue: DispatchQueue?,
        commitNotificationBlock: ((Result<Int, Error>?) -> Void)?
    ) {
        guard !cancellableStore.hasCall else {
            return
        }

        // always provide sorted to utilize the cache
        let sortedPrices = Array(priceIds).sorted()

        let fetchOperation = CoingeckoOperationFactory().fetchPriceOperation(
            for: sortedPrices,
            currency: currency
        )

        let saveOperation = repository.replaceOperation {
            try fetchOperation.extractNoCancellableResultData()
        }

        saveOperation.addDependency(fetchOperation)

        let wrapper = CompoundOperationWrapper(
            targetOperation: saveOperation,
            dependencies: [fetchOperation]
        )

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: cancellableStore,
            runningCallbackIn: queue ?? self.queue
        ) { _ in
            do {
                let prices = try fetchOperation.extractNoCancellableResultData()
                commitNotificationBlock?(.success(prices.count))
            } catch {
                commitNotificationBlock?(.failure(error))
            }
        }
    }
}

private extension CoingeckoStreamableSource {
    func subscribe() {
        cancellable = priceIdsObservable
            .receive(on: queue)
            .sink { [weak self] in
                self?.priceIds = $0
            }
    }
}
