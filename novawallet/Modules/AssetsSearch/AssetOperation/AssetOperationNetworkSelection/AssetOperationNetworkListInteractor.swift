import UIKit
import Operation_iOS

final class AssetOperationNetworkListInteractor {
    weak var presenter: AssetOperationNetworkListInteractorOutputProtocol?

    private let stateObservable: AssetListModelObservable
    private let multichainToken: MultichainToken
    private let operationQueue: OperationQueue

    private let logger: LoggerProtocol

    private var chainAssets: [ChainAsset] = []

    private var builder: AssetOperationNetworkBuilder?

    init(
        multichainToken: MultichainToken,
        operationQueue: OperationQueue,
        stateObservable: AssetListModelObservable,
        logger: LoggerProtocol
    ) {
        self.multichainToken = multichainToken
        self.operationQueue = operationQueue
        self.stateObservable = stateObservable
        self.logger = logger
    }
}

// MARK: AssetOperationNetworkSelectionInteractorInputProtocol

extension AssetOperationNetworkListInteractor: AssetOperationNetworkListInteractorInputProtocol {
    func setup() {
        let chainAssetIds = Set(multichainToken.instances.map(\.chainAssetId))

        let chainAssets = multichainToken.instances
            .compactMap { chainAsset in
                let chainId = chainAsset.chainAssetId.chainId

                return stateObservable.state.value.allChains[chainId]?.chainAssets()
            }
            .flatMap { $0 }
            .filter { chainAssetIds.contains($0.chainAssetId) }

        let resultClosure: (AssetOperationNetworkBuilderResult?) -> Void = { [weak self] result in
            guard let result else { return }

            self?.presenter?.didReceive(result: result)
        }

        builder = .init(
            chainAssets: chainAssets,
            workingQueue: .main,
            callbackQueue: .main,
            callbackClosure: resultClosure,
            operationQueue: operationQueue,
            logger: logger
        )

        builder?.apply(model: stateObservable.state.value)

        stateObservable.addObserver(with: self) { [weak self] _, newState in
            self?.builder?.apply(model: newState.value)
        }
    }
}
