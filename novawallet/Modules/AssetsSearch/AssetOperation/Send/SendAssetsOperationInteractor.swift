import BigInt

final class SendAssetsOperationInteractor {
    weak var presenter: AssetsSearchInteractorOutputProtocol?

    let stateObservable: AssetListModelObservable
    let filter: ChainAssetsFilter
    let logger: LoggerProtocol

    private var builder: AssetSearchBuilder?

    init(
        stateObservable: AssetListModelObservable,
        logger: LoggerProtocol
    ) {
        self.stateObservable = stateObservable
        self.logger = logger

        filter = { chainAsset in
            let assetMapper = CustomAssetMapper(type: chainAsset.asset.type, typeExtras: chainAsset.asset.typeExtras)

            guard let transfersEnabled = try? assetMapper.transfersEnabled(), transfersEnabled else {
                return false
            }
            guard let balance = try? stateObservable.state.value.balances[chainAsset.chainAssetId]?.get() else {
                return false
            }

            return balance.transferable > 0
        }
    }
}

extension SendAssetsOperationInteractor: AssetsSearchInteractorInputProtocol {
    func setup() {
        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1

        builder = .init(
            filter: filter,
            state: stateObservable.state.value.assetListState(balancePart: \.transferable),
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
            guard let self = self else {
                return
            }
            self.builder?.apply(state: newState.value.assetListState(balancePart: \.transferable))
        }
    }

    func search(query: String) {
        builder?.apply(query: query)
    }
}
