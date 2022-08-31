import Foundation
import CommonWallet
import BigInt

final class StakingMainPresenter {
    weak var view: StakingMainViewProtocol?
    var wireframe: StakingMainWireframeProtocol!
    var interactor: StakingMainInteractorInputProtocol!

    let childPresenterFactory: StakingMainPresenterFactoryProtocol
    let viewModelFactory: StakingMainViewModelFactoryProtocol
    let accountManagementFilter: AccountManagementFilterProtocol
    let logger: LoggerProtocol?

    private var childPresenter: StakingMainChildPresenterProtocol?
    private var wallet: MetaAccountModel?
    private var chainAsset: ChainAsset?
    private var accountInfo: AccountInfo?

    init(
        childPresenterFactory: StakingMainPresenterFactoryProtocol,
        viewModelFactory: StakingMainViewModelFactoryProtocol,
        accountManagementFilter: AccountManagementFilterProtocol,
        logger: LoggerProtocol?
    ) {
        self.childPresenterFactory = childPresenterFactory
        self.viewModelFactory = viewModelFactory
        self.accountManagementFilter = accountManagementFilter
        self.logger = logger
    }

    private func provideMainViewModel() {
        guard let chainAsset = chainAsset, let wallet = wallet else {
            return
        }

        let viewModel = viewModelFactory.createMainViewModel(
            from: wallet,
            chainAsset: chainAsset,
            balance: accountInfo?.data.available
        )

        view?.didReceive(viewModel: viewModel)
    }
}

// MARK: - StakingMainPresenterProtocol

extension StakingMainPresenter: StakingMainPresenterProtocol {
    func setup() {
        // setup default view state
        view?.didReceiveStakingState(viewModel: .undefined)

        provideMainViewModel()

        interactor.setup()
    }

    func performAssetSelection() {
        wireframe.showChainAssetSelection(
            from: view,
            selectedChainAssetId: chainAsset?.chainAssetId,
            delegate: self
        )
    }

    func performMainAction() {
        guard let chain = chainAsset?.chain, let wallet = wallet else {
            return
        }

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

    func performAccountAction() {
        wireframe.showWalletSwitch(from: view)
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

    func performAnalyticsAction() {
        childPresenter?.performAnalyticsAction()
    }

    func networkInfoViewDidChangeExpansion(isExpanded: Bool) {
        interactor.saveNetworkInfoViewExpansion(isExpanded: isExpanded)
    }

    func performManageAction(_ action: StakingManageOption) {
        childPresenter?.performManageAction(action)
    }
}

extension StakingMainPresenter: StakingMainInteractorOutputProtocol {
    func didReceiveError(_ error: Error) {
        let locale = view?.localizationManager?.selectedLocale

        if !wireframe.present(error: error, from: view, locale: locale) {
            logger?.error("Did receive error: \(error)")
        }
    }

    func didReceiveSelectedAccount(_ metaAccount: MetaAccountModel) {
        wallet = metaAccount

        provideMainViewModel()
    }

    func didReceiveStakingSettings(_ stakingSettings: StakingAssetSettings) {
        let oldChainAsset = chainAsset
        chainAsset = stakingSettings.value

        provideMainViewModel()

        if oldChainAsset != chainAsset, let view = view {
            childPresenter = childPresenterFactory.createPresenter(
                for: stakingSettings,
                view: view
            )

            childPresenter?.setup()
        }
    }

    func didReceiveAccountInfo(_ accountInfo: AccountInfo?) {
        self.accountInfo = accountInfo

        provideMainViewModel()
    }

    func didReceiveExpansion(_ isExpanded: Bool) {
        view?.expandNetworkInfoView(isExpanded)
    }
}

extension StakingMainPresenter: AssetSelectionDelegate {
    func assetSelection(view _: AssetSelectionViewProtocol, didCompleteWith chainAsset: ChainAsset) {
        interactor.save(chainAsset: chainAsset)
    }
}
