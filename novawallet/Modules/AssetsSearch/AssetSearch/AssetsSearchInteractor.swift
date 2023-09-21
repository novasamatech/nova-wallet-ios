import UIKit

final class AssetsSearchInteractor {
    weak var presenter: AssetsSearchInteractorOutputProtocol?

    let stateObservable: AssetListModelObservable
    let filter: ChainAssetsFilter?
    let logger: LoggerProtocol

    private var builder: AssetSearchBuilder?

    init(
        stateObservable: AssetListModelObservable,
        filter: ChainAssetsFilter?,
        logger: LoggerProtocol
    ) {
        self.stateObservable = stateObservable
        self.filter = filter
        self.logger = logger
    }
}

extension AssetsSearchInteractor: AssetsSearchInteractorInputProtocol {
    func setup() {
        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1

        builder = .init(
            filter: filter,
            model: stateObservable.state.value,
            workingQueue: .main,
            callbackQueue: .main,
            callbackClosure: { [weak self] result in
                self?.presenter?.didReceive(result: result)
            },
            operationQueue: operationQueue,
            logger: logger
        )

        builder?.apply(query: "")

        stateObservable.addObserver(with: self) { [weak self] _, newState in
            self?.builder?.apply(model: newState.value)
        }
    }

    func search(query: String) {
        builder?.apply(query: query)
    }
}
