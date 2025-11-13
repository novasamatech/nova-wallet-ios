import Foundation
import BigInt
import Keystore_iOS

final class GiftAssetsOperationInteractor {
    weak var presenter: AssetsSearchInteractorOutputProtocol?

    let stateObservable: AssetListModelObservable
    let filter: ChainAssetsFilter
    let settingsManager: SettingsManagerProtocol
    let assetTransferAggregationFactory: AssetTransferAggregationFactoryProtocol
    let assetSufficiencyProvider: AssetExchangeSufficiencyProviding
    let logger: LoggerProtocol

    private var builder: GiftAssetSearchBuilder?

    init(
        stateObservable: AssetListModelObservable,
        filter: @escaping ChainAssetsFilter,
        settingsManager: SettingsManagerProtocol,
        assetTransferAggregationFactory: AssetTransferAggregationFactoryProtocol,
        assetSufficiencyProvider: AssetExchangeSufficiencyProviding,
        logger: LoggerProtocol
    ) {
        self.stateObservable = stateObservable
        self.filter = filter
        self.settingsManager = settingsManager
        self.assetTransferAggregationFactory = assetTransferAggregationFactory
        self.assetSufficiencyProvider = assetSufficiencyProvider
        self.logger = logger
    }

    private func provideAssetsGroupStyle() {
        let style = settingsManager.assetListGroupStyle

        presenter?.didReceiveAssetGroupsStyle(style)
    }
}

extension GiftAssetsOperationInteractor: AssetsSearchInteractorInputProtocol {
    func setup() {
        provideAssetsGroupStyle()

        let operationQueue = OperationQueue()

        builder = .init(
            assetTransferAggregationFactory: assetTransferAggregationFactory,
            sufficiencyProvider: assetSufficiencyProvider,
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
