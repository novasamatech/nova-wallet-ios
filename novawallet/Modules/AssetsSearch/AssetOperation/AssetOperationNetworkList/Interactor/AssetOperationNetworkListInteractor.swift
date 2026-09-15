import UIKit
import Operation_iOS

class AssetOperationNetworkListInteractor {
    weak var presenter: AssetOperationNetworkListInteractorOutputProtocol?

    let workingQueueLabel: String = "com.nova.wallet.assets.networks.builder"
    let stateObservable: AssetListModelObservable
    let multichainToken: MultichainToken
    let includesHiddenAssets: Bool

    let logger: LoggerProtocol

    private var chainAssets: [ChainAsset] = []

    private var builder: AssetOperationNetworkBuilder?

    init(
        multichainToken: MultichainToken,
        stateObservable: AssetListModelObservable,
        includesHiddenAssets: Bool,
        logger: LoggerProtocol
    ) {
        self.multichainToken = multichainToken
        self.stateObservable = stateObservable
        self.includesHiddenAssets = includesHiddenAssets
        self.logger = logger
    }

    func createModelBuilder(
        with chainAssets: [ChainAsset],
        resultClosure: @escaping (AssetOperationNetworkBuilderResult?) -> Void
    ) -> AssetOperationNetworkBuilder {
        .init(
            chainAssets: chainAssets,
            includesHiddenAssets: includesHiddenAssets,
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
        let chains = stateObservable.state.value.chains(includingHidden: includesHiddenAssets)

        let chainAssets = multichainToken.instances.compactMap { instance in
            chains[instance.chainAssetId.chainId]?.chainAsset(for: instance.chainAssetId.assetId)
        }

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
