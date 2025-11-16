import UIKit
import Operation_iOS

final class GiftListInteractor {
    weak var presenter: GiftListInteractorOutputProtocol?

    private let repository: AnyDataProviderRepository<GiftModel>
    private let operationQueue: OperationQueue

    init(
        repository: AnyDataProviderRepository<GiftModel>,
        operationQueue: OperationQueue
    ) {
        self.repository = repository
        self.operationQueue = operationQueue
    }
}

// MARK: - Private

private extension GiftListInteractor {
    func provideGifts() {
        let fetchOperation = repository.fetchAllOperation(with: .init())

        execute(
            operation: fetchOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(gifts):
                self?.presenter?.didReceive(gifts)
            case let .failure(error):
                self?.presenter?.didReceive(error)
            }
        }
    }
}

// MARK: - GiftListInteractorInputProtocol

extension GiftListInteractor: GiftListInteractorInputProtocol {
    func setup() {
        provideGifts()
    }

    func fetchGifts() {
        provideGifts()
    }
}
