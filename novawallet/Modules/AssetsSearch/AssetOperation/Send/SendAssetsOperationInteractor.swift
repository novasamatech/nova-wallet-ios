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
        filter: @escaping ChainAssetsFilter,
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
