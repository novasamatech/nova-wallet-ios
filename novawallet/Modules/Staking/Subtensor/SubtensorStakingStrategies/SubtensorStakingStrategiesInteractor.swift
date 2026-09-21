import Foundation
import Operation_iOS

final class SubtensorStakingStrategiesInteractor: AnyCancellableCleaning {
    weak var presenter: SubtensorStakingStrategiesInteractorOutputProtocol?

    let dataSource: SubtensorStakingStrategiesDataSourceProtocol
    let operationQueue: OperationQueue

    private var cancellableStore = CancellableCallStore()

    init(
        dataSource: SubtensorStakingStrategiesDataSourceProtocol,
        operationQueue: OperationQueue
    ) {
        self.dataSource = dataSource
        self.operationQueue = operationQueue
    }

    deinit {
        cancellableStore.cancel()
    }
}

private extension SubtensorStakingStrategiesInteractor {
    func fetchStrategies() {
        cancellableStore.cancel()

        executeCancellable(
            wrapper: dataSource.fetchStrategies(),
            inOperationQueue: operationQueue,
            backingCallIn: cancellableStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(strategies):
                self?.presenter?.didReceive(strategies: strategies)
            case let .failure(error):
                self?.presenter?.didReceive(error: error)
            }
        }
    }
}

extension SubtensorStakingStrategiesInteractor: SubtensorStakingStrategiesInteractorInputProtocol {
    func setup() {
        fetchStrategies()
    }

    func retry() {
        fetchStrategies()
    }
}
