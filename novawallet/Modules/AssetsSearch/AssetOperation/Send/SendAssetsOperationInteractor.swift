import BigInt

final class SendAssetsOperationInteractor {
    weak var presenter: AssetsSearchInteractorOutputProtocol?

    let stateObservable: AssetListStateObservable
    let filter: ChainAssetsFilter
    let logger: LoggerProtocol

    private var builder: AssetSearchBuilder?

    init(
        stateObservable: AssetListStateObservable,
        logger: LoggerProtocol
    ) {
        self.stateObservable = stateObservable
        self.logger = logger

        filter = { chainAsset in
            let assetMapper = CustomAssetMapper(type: chainAsset.asset.type, typeExtras: chainAsset.asset.typeExtras)

            guard let transfersEnabled = try? assetMapper.transfersEnabled(), transfersEnabled else {
                return false
            }
            guard let balance = try? stateObservable.state.value.balanceResults[chainAsset.chainAssetId]?.get() else {
                return false
            }

            return balance > 0
        }
    }
}

extension SendAssetsOperationInteractor: AssetsSearchInteractorInputProtocol {
    func setup() {
        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1

        builder = .init(
            filter: filter,
            state: createState(from: stateObservable.state.value),
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
            self.builder?.apply(state: self.createState(from: newState.value))
        }
    }

    func createState(from state: AssetListState) -> AssetListState {
        let balanceResults = state.balances.reduce(into: [ChainAssetId: Result<BigUInt, Error>]()) {
            switch $1.value {
            case let .success(balance):
                $0[$1.key] = .success(balance.transferable ?? 0)
            case let .failure(error):
                $0[$1.key] = .failure(error)
            }
        }

        return AssetListState(
            priceResult: state.priceResult,
            balanceResults: balanceResults,
            allChains: state.allChains,
            balances: state.balances
        )
    }

    func search(query: String) {
        builder?.apply(query: query)
    }
}
