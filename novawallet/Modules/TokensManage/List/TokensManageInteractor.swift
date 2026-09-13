import Foundation
import Operation_iOS
import Keystore_iOS

final class TokensManageInteractor: AnyProviderAutoCleaning {
    weak var presenter: TokensManageInteractorOutputProtocol?

    let chainRegistry: ChainRegistryProtocol
    let selectedWalletSettings: SelectedWalletSettings
    let settingsManager: SettingsManagerProtocol
    let assetVisibilitySubscriptionFactory: AssetVisibilityLocalSubscriptionFactoryProtocol
    let visibilityWriter: AssetVisibilityWriting
    let settingsRepository: AnyDataProviderRepository<MetaAccountSettingsLocal>
    let defaultAssetsProvider: DefaultAssetsProviding
    let operationQueue: OperationQueue
    let settingsSaveQueue: OperationQueue
    let logger: LoggerProtocol

    private var visibilityProvider: StreamableProvider<AssetVisibilityLocal>?
    private var settingsProvider: StreamableProvider<MetaAccountSettingsLocal>?

    init(
        chainRegistry: ChainRegistryProtocol,
        selectedWalletSettings: SelectedWalletSettings,
        settingsManager: SettingsManagerProtocol,
        assetVisibilitySubscriptionFactory: AssetVisibilityLocalSubscriptionFactoryProtocol,
        visibilityWriter: AssetVisibilityWriting,
        settingsRepository: AnyDataProviderRepository<MetaAccountSettingsLocal>,
        defaultAssetsProvider: DefaultAssetsProviding,
        operationQueue: OperationQueue,
        settingsSaveQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.selectedWalletSettings = selectedWalletSettings
        self.settingsManager = settingsManager
        self.assetVisibilitySubscriptionFactory = assetVisibilitySubscriptionFactory
        self.visibilityWriter = visibilityWriter
        self.settingsRepository = settingsRepository
        self.defaultAssetsProvider = defaultAssetsProvider
        self.operationQueue = operationQueue
        self.settingsSaveQueue = settingsSaveQueue
        self.logger = logger
    }
}

// MARK: TokensManageInteractorInputProtocol

extension TokensManageInteractor: TokensManageInteractorInputProtocol {
    func setup() {
        presenter?.didReceiveGroupStyle(settingsManager.assetListGroupStyle)

        subscribeChains()
        fetchDefaultAssets()
        subscribeVisibilityAfterSeed()
    }

    func save(chainAssetIds: Set<ChainAssetId>, state: AssetVisibilityState) {
        guard let metaId = selectedWalletSettings.value?.metaId else {
            return
        }

        visibilityWriter.setState(
            metaId: metaId,
            ids: chainAssetIds,
            state: state,
            runningCallbackIn: .main
        ) { [weak self] result in
            if case .failure = result {
                self?.presenter?.didFailSave()
            }
        }
    }

    func save(autoAddTokensWithBalance: Bool) {
        guard let metaId = selectedWalletSettings.value?.metaId else {
            return
        }

        let settings = MetaAccountSettingsLocal(
            metaId: metaId,
            autoAddTokensWithBalance: autoAddTokensWithBalance
        )

        let saveOperation = settingsRepository.saveOperation({ [settings] }, { [] })

        execute(
            operation: saveOperation,
            inOperationQueue: settingsSaveQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            if case let .failure(error) = result {
                self?.logger.error("Can't save the auto add setting: \(error)")
                self?.presenter?.didFailSave()
            }
        }
    }
}

// MARK: AssetVisibilityLocalStorageSubscriber

extension TokensManageInteractor: AssetVisibilityLocalStorageSubscriber, AssetVisibilitySubscriptionHandler {
    func handleAssetVisibility(
        result: Result<[DataProviderChange<AssetVisibilityLocal>], Error>,
        metaId: MetaAccountModel.Id
    ) {
        guard metaId == selectedWalletSettings.value?.metaId else {
            return
        }

        switch result {
        case let .success(changes):
            presenter?.didReceiveVisibility(changes: changes)
        case let .failure(error):
            logger.error("Can't observe asset visibility: \(error)")
        }
    }

    func handleMetaAccountSettings(
        result: Result<[DataProviderChange<MetaAccountSettingsLocal>], Error>,
        metaId: MetaAccountModel.Id
    ) {
        guard metaId == selectedWalletSettings.value?.metaId else {
            return
        }

        switch result {
        case let .success(changes):
            let enabled = changes.reduceToLastChange()?.autoAddTokensWithBalance
                ?? MetaAccountSettingsLocal.defaultAutoAddTokensWithBalance

            presenter?.didReceiveAutoAddTokens(enabled: enabled)
        case let .failure(error):
            logger.error("Can't observe the auto add setting: \(error)")
        }
    }
}

// MARK: Private

private extension TokensManageInteractor {
    func subscribeChains() {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: .main,
            filterStrategy: nil
        ) { [weak self] changes in
            self?.presenter?.didReceiveChainModel(changes: changes)
        }
    }

    func fetchDefaultAssets() {
        let wrapper = defaultAssetsProvider.createDefaultAssetsWrapper()

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(list):
                self?.presenter?.didReceiveDefaultAssets(list)
            case let .failure(error):
                self?.logger.error("Default assets are unavailable: \(error)")
                self?.presenter?.didReceiveDefaultAssets(.empty)
            }
        }
    }

    func subscribeVisibilityAfterSeed() {
        visibilityWriter.enqueueBarrier(callbackIn: .main) { [weak self] in
            self?.subscribeVisibility()
        }
    }

    func subscribeVisibility() {
        clear(streamableProvider: &visibilityProvider)
        clear(streamableProvider: &settingsProvider)

        guard let metaId = selectedWalletSettings.value?.metaId else {
            return
        }

        visibilityProvider = subscribeToAssetVisibilityProvider(for: metaId)
        settingsProvider = subscribeToMetaAccountSettingsProvider(for: metaId)
    }
}
