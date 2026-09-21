import Foundation
import Operation_iOS

final class StartStakingInfoSubtensorPreviewInteractor: AnyCancellableCleaning {
    weak var presenter: StartStakingInfoSubtensorPreviewInteractorOutputProtocol?

    let dataSource: SubtensorStakingPreviewDataSourceProtocol
    let operationQueue: OperationQueue

    private var cancellableStore = CancellableCallStore()

    init(
        dataSource: SubtensorStakingPreviewDataSourceProtocol,
        operationQueue: OperationQueue
    ) {
        self.dataSource = dataSource
        self.operationQueue = operationQueue
    }

    deinit {
        cancellableStore.cancel()
    }
}

private extension StartStakingInfoSubtensorPreviewInteractor {
    func fetchPreviewData() {
        cancellableStore.cancel()

        executeCancellable(
            wrapper: dataSource.fetchPreviewData(),
            inOperationQueue: operationQueue,
            backingCallIn: cancellableStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(previewData):
                self?.presenter?.didReceive(previewData: previewData)
            case let .failure(error):
                self?.presenter?.didReceivePreview(error: error)
            }
        }
    }
}

extension StartStakingInfoSubtensorPreviewInteractor: StartStakingInfoSubtensorPreviewInteractorInputProtocol {
    func setup() {
        fetchPreviewData()
    }

    func retry() {
        fetchPreviewData()
    }
}
