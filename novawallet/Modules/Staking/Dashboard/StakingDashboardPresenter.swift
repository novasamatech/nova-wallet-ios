import Foundation
import Operation_iOS
import Foundation_iOS
import NovaAnalytics

final class StakingDashboardPresenter: AnalyticsTracking {
    weak var view: StakingDashboardViewProtocol?
    let wireframe: StakingDashboardWireframeProtocol
    let interactor: StakingDashboardInteractorInputProtocol
    let viewModelFactory: StakingDashboardViewModelFactoryProtocol
    let announcementViewModelFactory: AnnouncementViewModelFactoryProtocol
    let logger: LoggerProtocol

    let walletViewModelFactory = WalletSwitchViewModelFactory()

    private var lastResult: StakingDashboardBuilderResult?
    private var wallet: MetaAccountModel?
    private var hasWalletsListUpdates: Bool = false
    private var announcements: [Announcement] = []
    private var pendingChainAssetId: ChainAssetId?
    private let pendingNavigationTimeout = Debouncer(delay: 10)

    init(
        interactor: StakingDashboardInteractorInputProtocol,
        wireframe: StakingDashboardWireframeProtocol,
        viewModelFactory: StakingDashboardViewModelFactoryProtocol,
        announcementViewModelFactory: AnnouncementViewModelFactoryProtocol,
        privacyStateManager: PrivacyStateManagerProtocol,
        localizationManager: LocalizationManagerProtocol,
        appearanceFacade: AppearanceFacadeProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.announcementViewModelFactory = announcementViewModelFactory
        self.logger = logger
        self.localizationManager = localizationManager
        self.privacyStateManager = privacyStateManager
        self.appearanceFacade = appearanceFacade
    }
}

// MARK: - Private

private extension StakingDashboardPresenter {
    func processPendingNavigation(waitingForSync: Bool) {
        guard let chainAssetId = pendingChainAssetId, let model = lastResult?.model else {
            return
        }

        if let item = model.active.first(where: { $0.chainAsset.chainAssetId == chainAssetId }) {
            clearPendingNavigation()

            wireframe.showStakingDetails(from: view, option: item.stakingOption)
            return
        }

        let startStakingItems: [StakingDashboardItemModelCommonProtocol] = model.inactive + model.more

        guard
            let item = startStakingItems.first(where: { $0.chainAsset.chainAssetId == chainAssetId }),
            !waitingForSync || !item.isOnchainSync
        else { return }

        clearPendingNavigation()

        showStartStaking(for: item.chainAsset, source: .deepLink)
    }

    func completePendingNavigation() {
        processPendingNavigation(waitingForSync: false)
        clearPendingNavigation()
    }

    func clearPendingNavigation() {
        pendingChainAssetId = nil
        pendingNavigationTimeout.cancel()
    }

    func showStartStaking(for chainAsset: ChainAsset, source: StakingFlowSource) {
        let event = chainAsset.chain.analyticsNetworkName.map { network in
            AnalyticsEvent.stakingFlowOpened(network: network, source: source)
        }

        trackAnalytics(event)

        wireframe.showStartStaking(from: view, chainAsset: chainAsset)
    }

    func updateWalletView() {
        guard let wallet = wallet else {
            return
        }

        let viewModel = walletViewModelFactory.createViewModel(
            from: wallet.identifier,
            walletIdenticon: wallet.walletIdenticonData(),
            walletType: wallet.type,
            hasNotification: hasWalletsListUpdates
        )

        view?.didReceiveWallet(viewModel: viewModel)
    }

    func updateStakingsView() {
        guard let result = lastResult else {
            return
        }

        switch result.changeKind {
        case .reload:
            reloadStakingView(using: result.model)
        case let .sync(syncChange):
            updateStakingView(using: result.model, syncChange: syncChange)
        }
    }

    func reloadStakingView(using model: StakingDashboardModel) {
        let viewModel = viewModelFactory.createViewModel(
            from: model,
            announcements: announcements,
            privacyModeEnabled: privacyModeEnabled,
            locale: selectedLocale
        )
        view?.didReceiveStakings(viewModel: viewModel)
    }

    func updateStakingView(
        using model: StakingDashboardModel,
        syncChange: StakingDashboardBuilderResult.SyncChange
    ) {
        let updateViewModel = viewModelFactory.createUpdateViewModel(
            from: model,
            announcements: announcements,
            syncChange: syncChange,
            privacyModeEnabled: privacyModeEnabled,
            locale: selectedLocale
        )

        view?.didReceiveUpdate(viewModel: updateViewModel)
    }
}

// MARK: - StakingDashboardPresenterProtocol

extension StakingDashboardPresenter: StakingDashboardPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func selectActiveStaking(at index: Int) {
        clearPendingNavigation()

        guard let option = lastResult?.model.active[index].stakingOption else {
            return
        }

        wireframe.showStakingDetails(from: view, option: option)
    }

    func selectInactiveStaking(at index: Int) {
        clearPendingNavigation()

        guard let item = lastResult?.model.inactive[index] else {
            return
        }

        showStartStaking(for: item.chainAsset, source: .dashboard)
    }

    func openStaking(for chainAssetId: ChainAssetId) {
        pendingChainAssetId = chainAssetId

        pendingNavigationTimeout.debounce { [weak self] in
            self?.completePendingNavigation()
        }

        processPendingNavigation(waitingForSync: true)
    }

    func cancelStakingOpening() {
        clearPendingNavigation()
    }

    func selectMoreOptions() {
        clearPendingNavigation()

        wireframe.showMoreOptions(from: view)
    }

    func selectAnnouncementLink(at index: Int) {
        clearPendingNavigation()

        let viewModels = announcementViewModelFactory.createGeneralViewModels(
            from: announcements,
            locale: selectedLocale
        )

        guard let url = viewModels[safe: index]?.link?.url else { return }

        wireframe.openBrowser(with: .query(string: url.absoluteString))
    }

    func switchWallet() {
        clearPendingNavigation()

        wireframe.showWalletSwitch(from: view)
    }

    func refresh() {
        interactor.refresh()
    }

    func becomeActive() {
        interactor.becomeActive()
    }
}

// MARK: - StakingDashboardInteractorOutputProtocol

extension StakingDashboardPresenter: StakingDashboardInteractorOutputProtocol {
    func didReceive(wallet: MetaAccountModel) {
        if let currentWallet = self.wallet, currentWallet.metaId != wallet.metaId {
            clearPendingNavigation()
        }

        self.wallet = wallet
        lastResult = StakingDashboardBuilderResult(
            walletId: wallet.metaId,
            model: .init(),
            changeKind: .reload
        )

        updateWalletView()
        updateStakingsView()
    }

    func didReceive(result: StakingDashboardBuilderResult) {
        guard wallet?.metaId == result.walletId else {
            return
        }

        lastResult = result

        updateStakingsView()
        processPendingNavigation(waitingForSync: true)
    }

    func didReceive(error: StakingDashboardInteractorError) {
        logger.error("Did receive error: \(error)")

        switch error {
        case .balanceFetchFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.retryBalancesSubscription()
            }
        case .priceFetchFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.retryPricesSubscription()
            }
        case .stakingsFetchFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.retryDashboardSubscription()
            }
        }
    }

    func didReceive(announcements: [Announcement]) {
        guard self.announcements != announcements else {
            return
        }

        self.announcements = announcements

        if let lastResult {
            reloadStakingView(using: lastResult.model)
        }
    }

    func didReceiveWalletsState(hasUpdates: Bool) {
        hasWalletsListUpdates = hasUpdates
        updateWalletView()
    }
}

// MARK: - Localizable

extension StakingDashboardPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateWalletView()

            if let lastResult {
                reloadStakingView(using: lastResult.model)
            }
        }
    }
}

// MARK: - PrivacyModeSupporting

extension StakingDashboardPresenter: PrivacyModeSupporting {
    func applyPrivacyMode() {
        guard
            let view,
            view.isSetup,
            let lastResult
        else { return }

        reloadStakingView(using: lastResult.model)
    }
}

// MARK: - IconAppearanceDepending

extension StakingDashboardPresenter: IconAppearanceDepending {
    func applyIconAppearance() {
        guard
            let view,
            view.isSetup,
            let lastResult
        else { return }

        reloadStakingView(using: lastResult.model)
    }
}
