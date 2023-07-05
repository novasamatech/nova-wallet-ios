import UIKit

final class AssetsSearchInteractor {
    weak var presenter: AssetsSearchInteractorOutputProtocol?

    let stateObservable: AssetListStateObservable
    let filter: ChainAssetsFilter?
    let logger: LoggerProtocol

    private var builder: AssetSearchBuilder?

    init(
        stateObservable: AssetListStateObservable,
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
            state: stateObservable.state.value,
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
            self?.builder?.apply(state: newState.value)
        }
    }

    func search(query: String) {
        builder?.apply(query: query)
    }
}
