import Foundation
import Operation_iOS
import Foundation_iOS

final class StakingDashboardPresenter {
    weak var view: StakingDashboardViewProtocol?
    let wireframe: StakingDashboardWireframeProtocol
    let interactor: StakingDashboardInteractorInputProtocol
    let viewModelFactory: StakingDashboardViewModelFactoryProtocol
    let privacyStateManager: PrivacyStateManagerProtocol
    let logger: LoggerProtocol

    let walletViewModelFactory = WalletSwitchViewModelFactory()

    private var lastResult: StakingDashboardBuilderResult?
    private var wallet: MetaAccountModel?
    private var hasWalletsListUpdates: Bool = false
    private var privacyModeEnabled: Bool = false

    init(
        interactor: StakingDashboardInteractorInputProtocol,
        wireframe: StakingDashboardWireframeProtocol,
        viewModelFactory: StakingDashboardViewModelFactoryProtocol,
        privacyStateManager: PrivacyStateManagerProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.privacyStateManager = privacyStateManager
        self.logger = logger
        self.localizationManager = localizationManager
    }
}

private extension StakingDashboardPresenter {
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
            syncChange: syncChange,
            privacyModeEnabled: privacyModeEnabled,
            locale: selectedLocale
        )

        view?.didReceiveUpdate(viewModel: updateViewModel)
    }

    func subscribePrivacyModeChanges() {
        privacyStateManager.addObserver(
            with: self,
            queue: .main
        ) { [weak self] _, privacyModeEnabled in
            self?.privacyModeEnabled = privacyModeEnabled

            guard let lastResult = self?.lastResult else { return }

            self?.reloadStakingView(using: lastResult.model)
        }
    }
}

extension StakingDashboardPresenter: StakingDashboardPresenterProtocol {
    func setup() {
        subscribePrivacyModeChanges()

        interactor.setup()
    }

    func selectActiveStaking(at index: Int) {
        guard let option = lastResult?.model.active[index].stakingOption else {
            return
        }

        wireframe.showStakingDetails(from: view, option: option)
    }

    func selectInactiveStaking(at index: Int) {
        guard let item = lastResult?.model.inactive[index] else {
            return
        }

        wireframe.showStartStaking(from: view, chainAsset: item.chainAsset)
    }

    func selectMoreOptions() {
        wireframe.showMoreOptions(from: view)
    }

    func switchWallet() {
        wireframe.showWalletSwitch(from: view)
    }

    func refresh() {
        interactor.refresh()
    }
}

extension StakingDashboardPresenter: StakingDashboardInteractorOutputProtocol {
    func didReceive(wallet: MetaAccountModel) {
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

    func didReceiveWalletsState(hasUpdates: Bool) {
        hasWalletsListUpdates = hasUpdates
        updateWalletView()
    }
}

extension StakingDashboardPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateWalletView()
            updateStakingsView()
        }
    }
}
