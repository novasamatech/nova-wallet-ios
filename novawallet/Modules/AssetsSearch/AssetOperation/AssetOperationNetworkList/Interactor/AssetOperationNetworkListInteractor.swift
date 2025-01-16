import UIKit
import Operation_iOS

class AssetOperationNetworkListInteractor {
    weak var presenter: AssetOperationNetworkListInteractorOutputProtocol?

    let workingQueueLabel: String = "com.nova.wallet.assets.networks.builder"
    let stateObservable: AssetListModelObservable
    let multichainToken: MultichainToken

    let logger: LoggerProtocol

    private var chainAssets: [ChainAsset] = []

    private var builder: AssetOperationNetworkBuilder?

    init(
        multichainToken: MultichainToken,
        stateObservable: AssetListModelObservable,
        logger: LoggerProtocol
    ) {
        self.multichainToken = multichainToken
        self.stateObservable = stateObservable
        self.logger = logger
    }

    func createModelBuilder(
        with chainAssets: [ChainAsset],
        resultClosure: @escaping (AssetOperationNetworkBuilderResult?) -> Void
    ) -> AssetOperationNetworkBuilder {
        .init(
            chainAssets: chainAssets,
            workingQueue: .init(
                label: workingQueueLabel,
                qos: .userInteractive
            ),
            callbackQueue: .main,
            callbackClosure: resultClosure,
            logger: logger
        )
    }
}

// MARK: AssetOperationNetworkListInteractorInputProtocol

extension AssetOperationNetworkListInteractor: AssetOperationNetworkListInteractorInputProtocol {
    func setup() {
        let chainAssetIds = Set(multichainToken.instances.map(\.chainAssetId))

        let chainAssets = multichainToken.instances
            .compactMap { instance in
                let chainId = instance.chainAssetId.chainId

                return stateObservable.state.value.allChains[chainId]?.chainAssets()
            }
            .flatMap { $0 }
            .filter { chainAssetIds.contains($0.chainAssetId) }

        let resultClosure: (AssetOperationNetworkBuilderResult?) -> Void = { [weak self] result in
            guard let result else { return }

            self?.presenter?.didReceive(result: result)
        }

        builder = createModelBuilder(
            with: chainAssets,
            resultClosure: resultClosure
        )

        builder?.apply(model: stateObservable.state.value)

        stateObservable.addObserver(with: self) { [weak self] _, newState in
            self?.builder?.apply(model: newState.value)
        }
    }
}
