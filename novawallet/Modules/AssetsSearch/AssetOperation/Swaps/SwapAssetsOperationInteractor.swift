import Foundation
import BigInt
import Keystore_iOS
import Operation_iOS

final class SwapAssetsOperationInteractor: AnyCancellableCleaning {
    weak var presenter: SwapAssetsOperationPresenterProtocol?

    let state: SwapTokensFlowStateProtocol
    let logger: LoggerProtocol
    let selectionModel: SwapAssetSelectionModel

    let settingsManager: SettingsManagerProtocol

    private let operationQueue: OperationQueue

    private var builder: SpendAssetSearchBuilder?
    private var reachabilityCallStore = CancellableCallStore()
    private var matchingAssets: Set<ChainAssetId>?

    private var assetExchangeService: AssetsExchangeServiceProtocol?

    init(
        state: SwapTokensFlowStateProtocol,
        selectionModel: SwapAssetSelectionModel,
        settingsManager: SettingsManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.state = state
        self.logger = logger
        self.selectionModel = selectionModel
        self.settingsManager = settingsManager
        self.operationQueue = operationQueue
    }

    deinit {
        reachabilityCallStore.cancel()
    }

    private func reloadDirectionsIfNeeded() {
        guard let assetExchangeService else {
            return
        }

        let wrapper = switch selectionModel {
        case let .payForAsset(chainAsset):
            assetExchangeService.fetchAssetsInWrapper(
                given: chainAsset?.chainAssetId
            )
        case let .receivePayingWith(chainAsset):
            assetExchangeService.fetchAssetsOutWrapper(
                given: chainAsset?.chainAssetId
            )
        }

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: reachabilityCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(matchingAssets):
                self?.matchingAssets = matchingAssets
                self?.builder?.reload()
            case let .failure(error):
                self?.presenter?.didReceive(error: .directions(error))
            }
        }
    }

    private func createBuilder() {
        let searchQueue = OperationQueue()
        searchQueue.maxConcurrentOperationCount = 1

        let filter: ChainAssetsFilter = { [weak self] chainAsset in
            guard let self, let matchingAssets else {
                return false
            }

            return matchingAssets.contains(chainAsset.chainAssetId)
        }

        builder = .init(
            filter: filter,
            workingQueue: .init(
                label: AssetsSearchInteractor.workingQueueLabel,
                qos: .userInteractive
            ),
            callbackQueue: .main,
            callbackClosure: { [weak self] result in
                self?.presenter?.didReceive(result: result)

                let hasNoDirections = self?.matchingAssets?.isEmpty ?? true
                self?.presenter?.didUpdate(hasDirections: !hasNoDirections)
            },
            operationQueue: searchQueue,
            logger: logger
        )

        builder?.apply(model: state.assetListObservable.state.value)

        state.assetListObservable.addObserver(with: self) { [weak self] _, newState in
            guard let self = self else {
                return
            }
            self.builder?.apply(model: newState.value)
        }
    }

    private func setupSwapService() {
        assetExchangeService = state.setupAssetExchangeService()

        assetExchangeService?.subscribeUpdates(
            for: self,
            notifyingIn: .main
        ) { [weak self] in
            self?.reloadDirectionsIfNeeded()
        }
    }

    private func provideAssetsGroupStyle() {
        let style = settingsManager.assetListGroupStyle

        presenter?.didReceiveAssetGroupsStyle(style)
    }
}

extension SwapAssetsOperationInteractor: SwapAssetsOperationInteractorInputProtocol {
    func setup() {
        provideAssetsGroupStyle()
        createBuilder()
        setupSwapService()
    }

    func search(query: String) {
        builder?.apply(query: query)
    }
}
