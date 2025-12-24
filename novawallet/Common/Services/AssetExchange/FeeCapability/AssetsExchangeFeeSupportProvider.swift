import Foundation
import Operation_iOS

final class AssetsExchangeFeeSupportProvider {
    let feeSupportFetchersProvider: AssetExchangeFeeSupportFetchersProviding
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private let syncQueue: DispatchQueue

    private var observableState: Observable<NotEqualWrapper<AssetExchangeFeeSupporting?>> = .init(
        state: .init(value: nil)
    )

    private var feeSupporters: [String: AssetExchangeFeeSupporting] = [:]
    private var feeFetchRequests: [String: CancellableCallStore] = [:]

    init(
        feeSupportFetchersProvider: AssetExchangeFeeSupportFetchersProviding,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.feeSupportFetchersProvider = feeSupportFetchersProvider
        self.operationQueue = operationQueue
        self.logger = logger

        syncQueue = DispatchQueue(label: "io.novawallet.exchangefeesupportprovider.\(UUID().uuidString)")
    }
}

private extension AssetsExchangeFeeSupportProvider {
    private func clearCurrentRequests() {
        feeFetchRequests.values.forEach { $0.cancel() }
    }

    private func updateFeeSupport(for fetchers: [AssetExchangeFeeSupportFetching]) {
        feeFetchRequests.values.forEach { $0.cancel() }
        feeFetchRequests = [:]

        let oldFeeSupportIds = Set(feeSupporters.keys)
        let newFeeSupportIds = Set(fetchers.map(\.identifier))

        let idsToRemove = oldFeeSupportIds.subtracting(newFeeSupportIds)

        if !idsToRemove.isEmpty {
            idsToRemove.forEach { feeSupporters[$0] = nil }
            rebuildFeeSupport()
        }

        fetchers.forEach { fetcher in
            let callStore = CancellableCallStore()
            feeFetchRequests[fetcher.identifier] = callStore

            let wrapper = fetcher.createFeeSupportWrapper()

            executeCancellable(
                wrapper: wrapper,
                inOperationQueue: operationQueue,
                backingCallIn: callStore,
                runningCallbackIn: syncQueue
            ) { [weak self] result in
                guard let self else {
                    return
                }

                switch result {
                case let .success(feeSupport):
                    logger.debug("Did receive fee support for \(fetcher.identifier).")

                    feeSupporters[fetcher.identifier] = feeSupport

                    rebuildFeeSupport()
                case let .failure(error):
                    logger.error("Did receive error \(fetcher.identifier): \(error).")
                }
            }
        }
    }

    private func rebuildFeeSupport() {
        let feeSupport = CompoundAssetExchangeFeeSupport(supporters: Array(feeSupporters.values))

        observableState.state = .init(value: feeSupport)
    }
}

extension AssetsExchangeFeeSupportProvider: AssetsExchangeFeeSupportProviding {
    func setup() {
        feeSupportFetchersProvider.setup()

        feeSupportFetchersProvider.subscribeFeeFetchers(
            self,
            notifyingIn: syncQueue
        ) { [weak self] fetchers in
            self?.updateFeeSupport(for: fetchers)
        }
    }

    func throttle() {
        feeSupportFetchersProvider.unsubscribeFeeFetchers(self)

        syncQueue.async {
            self.clearCurrentRequests()
        }
    }

    func subscribeFeeSupport(
        _ target: AnyObject,
        notifyingIn queue: DispatchQueue,
        onChange: @escaping (AssetExchangeFeeSupporting?) -> Void
    ) {
        syncQueue.async { [weak self] in
            self?.observableState.addObserver(
                with: target,
                sendStateOnSubscription: true,
                queue: queue
            ) { _, newState in
                onChange(newState.value)
            }
        }
    }

    func unsubscribe(_ target: AnyObject) {
        syncQueue.async { [weak self] in
            self?.observableState.removeObserver(by: target)
        }
    }

    func fetchCurrentState(
        in queue: DispatchQueue,
        completionClosure: @escaping (AssetExchangeFeeSupporting?) -> Void
    ) {
        syncQueue.async {
            let stateValue = self.observableState.state.value

            dispatchInQueueWhenPossible(queue) {
                completionClosure(stateValue)
            }
        }
    }
}
