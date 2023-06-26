import Foundation
import CommonWallet
import BigInt

final class StakingMainPresenter {
    weak var view: StakingMainViewProtocol?
    let interactor: StakingMainInteractorInputProtocol
    let wireframe: StakingMainWireframeProtocol

    let childPresenterFactory: StakingMainPresenterFactoryProtocol
    let viewModelFactory: StakingMainViewModelFactoryProtocol
    let stakingOption: Multistaking.ChainAssetOption
    let logger: LoggerProtocol?
    let wallet: MetaAccountModel
    let accountManagementFilter: AccountManagementFilterProtocol

    private var childPresenter: StakingMainChildPresenterProtocol?

    init(
        interactor: StakingMainInteractorInputProtocol,
        wireframe: StakingMainWireframeProtocol,
        wallet: MetaAccountModel,
        stakingOption: Multistaking.ChainAssetOption,
        accountManagementFilter: AccountManagementFilterProtocol,
        childPresenterFactory: StakingMainPresenterFactoryProtocol,
        viewModelFactory: StakingMainViewModelFactoryProtocol,
        logger: LoggerProtocol?
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.wallet = wallet
        self.stakingOption = stakingOption
        self.accountManagementFilter = accountManagementFilter
        self.childPresenterFactory = childPresenterFactory
        self.viewModelFactory = viewModelFactory
        self.logger = logger
    }

    private func provideMainViewModel() {
        let viewModel = viewModelFactory.createMainViewModel(chainAsset: stakingOption.chainAsset)

        view?.didReceive(viewModel: viewModel)
    }
}

// MARK: - StakingMainPresenterProtocol

extension StakingMainPresenter: StakingMainPresenterProtocol {
    func setup() {
        // setup default view state
        view?.didReceiveStakingState(viewModel: .undefined)

        provideMainViewModel()

        if childPresenter == nil, let view = view {
            childPresenter = childPresenterFactory.createPresenter(
                for: stakingOption,
                view: view
            )

            childPresenter?.setup()
        }

        interactor.setup()
    }

    func performMainAction() {
        let chain = stakingOption.chainAsset.chain

        if wallet.fetchMetaChainAccount(for: chain.accountRequest()) != nil {
            childPresenter?.performMainAction()
        } else if accountManagementFilter.canAddAccount(to: wallet, chain: chain) {
            guard let view = view else {
                return
            }

            let locale = view.selectedLocale

            let message = R.string.localizable.commonChainAccountMissingMessageFormat(
                chain.name,
                preferredLanguages: locale.rLanguages
            )

            wireframe.presentAddAccount(
                from: view,
                chainName: chain.name,
                message: message,
                locale: locale
            ) { [weak self] in
                guard let wallet = self?.wallet else {
                    return
                }

                self?.wireframe.showWalletDetails(from: self?.view, wallet: wallet)
            }
        } else {
            guard let view = view, let locale = view.localizationManager?.selectedLocale else {
                return
            }

            wireframe.presentNoAccountSupport(
                from: view,
                walletType: wallet.type,
                chainName: chain.name,
                locale: locale
            )
        }
    }

    func performRewardInfoAction() {
        childPresenter?.performRewardInfoAction()
    }

    func performChangeValidatorsAction() {
        childPresenter?.performChangeValidatorsAction()
    }

    func performSetupValidatorsForBondedAction() {
        childPresenter?.performSetupValidatorsForBondedAction()
    }

    func performStakeMoreAction() {
        childPresenter?.performStakeMoreAction()
    }

    func performRedeemAction() {
        childPresenter?.performRedeemAction()
    }

    func performRebondAction() {
        childPresenter?.performRebondAction()
    }

    func performRebag() {
        childPresenter?.performRebag()
    }

    func networkInfoViewDidChangeExpansion(isExpanded: Bool) {
        interactor.saveNetworkInfoViewExpansion(isExpanded: isExpanded)
    }

    func performManageAction(_ action: StakingManageOption) {
        childPresenter?.performManageAction(action)
    }
}

extension StakingMainPresenter: StakingMainInteractorOutputProtocol {
    func didReceiveExpansion(_ isExpanded: Bool) {
        view?.expandNetworkInfoView(isExpanded)
    }
}
