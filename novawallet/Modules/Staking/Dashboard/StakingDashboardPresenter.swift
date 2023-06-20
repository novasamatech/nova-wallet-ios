import Foundation
import RobinHood
import SoraFoundation

final class StakingDashboardPresenter {
    weak var view: StakingDashboardViewProtocol?
    let wireframe: StakingDashboardWireframeProtocol
    let interactor: StakingDashboardInteractorInputProtocol
    let viewModelFactory: StakingDashboardViewModelFactoryProtocol
    let logger: LoggerProtocol

    let walletViewModelFactory = WalletSwitchViewModelFactory()

    private var model: StakingDashboardModel?
    private var wallet: MetaAccountModel?

    init(
        interactor: StakingDashboardInteractorInputProtocol,
        wireframe: StakingDashboardWireframeProtocol,
        viewModelFactory: StakingDashboardViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func updateWalletView() {
        guard let wallet = wallet else {
            return
        }

        let viewModel = walletViewModelFactory.createViewModel(
            from: wallet.walletIdenticonData(),
            walletType: wallet.type
        )

        view?.didReceiveWallet(viewModel: viewModel)
    }

    private func updateStakingsView() {
        guard let model = model else {
            return
        }

        let viewModel = viewModelFactory.createViewModel(from: model, locale: selectedLocale)

        view?.didReceiveStakings(viewModel: viewModel)
    }
}

extension StakingDashboardPresenter: StakingDashboardPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func selectActiveStaking(at index: Int) {
        guard let option = model?.active[index].stakingOption else {
            return
        }

        wireframe.showStakingDetails(from: view, option: option)
    }

    func selectInactiveStaking(at index: Int) {
        guard let option = model?.inactive[index].stakingOption else {
            return
        }

        wireframe.showStakingDetails(from: view, option: option)
    }

    func selectMoreOptions() {}

    func switchWallet() {
        wireframe.showWalletSwitch(from: view)
    }

    func refresh() {}
}

extension StakingDashboardPresenter: StakingDashboardInteractorOutputProtocol {
    func didReceive(wallet: MetaAccountModel) {
        self.wallet = wallet

        updateWalletView()
    }

    func didReceive(model: StakingDashboardModel) {
        self.model = model

        updateStakingsView()
    }

    func didReceive(error: StakingDashboardInteractorError) {
        logger.debug("Did receive error: \(error)")

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
}

extension StakingDashboardPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateWalletView()
            updateStakingsView()
        }
    }
}
