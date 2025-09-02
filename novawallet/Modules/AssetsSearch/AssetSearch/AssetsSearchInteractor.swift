import UIKit
import Keystore_iOS

final class AssetsSearchInteractor {
    static let workingQueueLabel: String = "com.nova.wallet.assets.search.builder"

    weak var presenter: AssetsSearchInteractorOutputProtocol?

    let stateObservable: AssetListModelObservable
    let filter: ChainAssetsFilter?
    let logger: LoggerProtocol

    let settingsManager: SettingsManagerProtocol

    private var builder: AssetSearchBuilder?

    init(
        stateObservable: AssetListModelObservable,
        filter: ChainAssetsFilter?,
        settingsManager: SettingsManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.stateObservable = stateObservable
        self.filter = filter
        self.settingsManager = settingsManager
        self.logger = logger
    }

    private func provideAssetsGroupStyle() {
        let style = settingsManager.assetListGroupStyle

        presenter?.didReceiveAssetGroupsStyle(style)
    }
}

extension AssetsSearchInteractor: AssetsSearchInteractorInputProtocol {
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
            self?.builder?.apply(model: newState.value)
        }
    }

    func search(query: String) {
        builder?.apply(query: query)
    }
}
