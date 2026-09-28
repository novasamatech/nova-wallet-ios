import Foundation
import Operation_iOS

final class SubtensorValidatorSelectInteractor: AnyCancellableCleaning {
    weak var presenter: ValidatorSelectInteractorOutputProtocol?

    private let directoryService: SubtensorValidatorDirectoryServiceProtocol
    private let yieldService: SubtensorYieldServiceProtocol
    private let operationQueue: OperationQueue
    private let logger: LoggerProtocol
    private let directoryStore = CancellableCallStore()
    private let yieldStore = CancellableCallStore()
    private let detailStore = CancellableCallStore()

    init(
        directoryService: SubtensorValidatorDirectoryServiceProtocol,
        yieldService: SubtensorYieldServiceProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.directoryService = directoryService
        self.yieldService = yieldService
        self.operationQueue = operationQueue
        self.logger = logger
    }

    deinit {
        directoryStore.cancel()
        yieldStore.cancel()
        detailStore.cancel()
    }
}

extension SubtensorValidatorSelectInteractor: ValidatorSelectInteractorInputProtocol {
    func loadDirectory(for subnet: SubtensorSubnetRef) {
        directoryStore.cancel()
        executeCancellable(
            wrapper: directoryService.createDirectoryWrapper(for: subnet),
            inOperationQueue: operationQueue,
            backingCallIn: directoryStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(directory): self?.presenter?.didReceive(directory: directory)
            case let .failure(error): self?.presenter?.didFailDirectory(error)
            }
        }
    }

    func loadYields(for netuid: UInt16) {
        yieldStore.cancel()
        executeCancellable(
            wrapper: yieldService.createAlphaYieldsWrapper(for: netuid),
            inOperationQueue: operationQueue,
            backingCallIn: yieldStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(yields): self?.presenter?.didReceive(yields: yields)
            case let .failure(error): self?.logger.warning("Subnet validator yields unavailable: \(error)")
            }
        }
    }

    func loadDetail(for item: SubtensorValidatorDirectoryItem, subnet: SubtensorSubnetRef) {
        detailStore.cancel()
        executeCancellable(
            wrapper: directoryService.createDetailWrapper(for: item.hotkey, subnet: subnet),
            inOperationQueue: operationQueue,
            backingCallIn: detailStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(detail): self?.presenter?.didReceive(detail: detail)
            case let .failure(error): self?.logger.warning("Validator detail unavailable: \(error)")
            }
        }
    }
}
