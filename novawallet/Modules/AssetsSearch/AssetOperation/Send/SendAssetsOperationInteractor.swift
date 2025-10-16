import Foundation
import BigInt
import Keystore_iOS

final class SendAssetsOperationInteractor {
    weak var presenter: AssetsSearchInteractorOutputProtocol?

    let stateObservable: AssetListModelObservable
    let filter: ChainAssetsFilter
    let settingsManager: SettingsManagerProtocol
    let logger: LoggerProtocol

    private var builder: SpendAssetSearchBuilder?

    init(
        stateObservable: AssetListModelObservable,
        settingsManager: SettingsManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.stateObservable = stateObservable
        self.settingsManager = settingsManager
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

    private func provideAssetsGroupStyle() {
        let style = settingsManager.assetListGroupStyle

        presenter?.didReceiveAssetGroupsStyle(style)
    }
}

extension SendAssetsOperationInteractor: AssetsSearchInteractorInputProtocol {
    func setup() {
        provideAssetsGroupStyle()

        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1

        builder = .init(
            filter: filter,
            workingQueue: .init(
                label: AssetsSearchInteractor.workingQueueLabel,
                qos: .userInteractive
            ),
            callbackQueue: .main,
            callbackClosure: { [weak self] result in
                self?.presenter?.didReceive(result: result)
            },
            operationQueue: operationQueue,
            logger: logger
        )

        builder?.apply(model: stateObservable.state.value)

        stateObservable.addObserver(with: self) { [weak self] _, newState in
            guard let self = self else {
                return
            }
            self.builder?.apply(model: newState.value)
        }
    }

    func search(query: String) {
        builder?.apply(query: query)
    }
}
