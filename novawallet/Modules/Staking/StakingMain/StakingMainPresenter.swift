import Foundation
import CommonWallet
import BigInt

final class StakingMainPresenter {
    weak var view: StakingMainViewProtocol?
    var wireframe: StakingMainWireframeProtocol!
    var interactor: StakingMainInteractorInputProtocol!

    let childPresenterFactory: StakingMainPresenterFactoryProtocol
    let viewModelFactory: StakingMainViewModelFactoryProtocol
    let logger: LoggerProtocol?

    private var childPresenter: StakingMainChildPresenterProtocol?
    private var wallet: MetaAccountModel?
    private var chainAsset: ChainAsset?
    private var accountInfo: AccountInfo?

    init(
        childPresenterFactory: StakingMainPresenterFactoryProtocol,
        viewModelFactory: StakingMainViewModelFactoryProtocol,
        logger: LoggerProtocol?
    ) {
        self.childPresenterFactory = childPresenterFactory
        self.viewModelFactory = viewModelFactory
        self.logger = logger
    }

    private func provideMainViewModel() {
        guard
            let chainAsset = chainAsset,
            let accountId = wallet?.substrateAccountId
        else {
            return
        }

        let viewModel = viewModelFactory.createMainViewModel(
            from: accountId,
            chainAsset: chainAsset,
            balance: accountInfo?.data.available
        )

        view?.didReceive(viewModel: viewModel)
    }

    private func createAccountCreateAction(for chain: ChainModel, wallet: MetaAccountModel) -> AlertPresentableAction {
        let createAccountTitle = R.string.localizable.accountCreateOptionTitle(
            preferredLanguages: view?.selectedLocale.rLanguages
        )

        return AlertPresentableAction(title: createAccountTitle) { [weak self] in
            self?.wireframe.showCreateAccount(from: self?.view, wallet: wallet, chain: chain)
        }
    }

    private func createAccountImportAction(for chain: ChainModel, wallet: MetaAccountModel) -> AlertPresentableAction {
        let importAccountTitle = R.string.localizable.accountImportOptionTitle(
            preferredLanguages: view?.selectedLocale.rLanguages
        )

        return AlertPresentableAction(title: importAccountTitle) { [weak self] in
            self?.wireframe.showImportAccount(from: self?.view, wallet: wallet, chain: chain)
        }
    }

    private func addAccount(for chain: ChainModel, wallet: MetaAccountModel) {
        let createAccountAction = createAccountCreateAction(for: chain, wallet: wallet)
        let importAccountAction = createAccountImportAction(for: chain, wallet: wallet)

        let actions: [AlertPresentableAction] = [createAccountAction, importAccountAction]

        let closeTitle = R.string.localizable.commonCancel(preferredLanguages: view?.selectedLocale.rLanguages)

        let title = R.string.localizable.accountNotFoundActionsTitle(
            chain.name,
            preferredLanguages: view?.selectedLocale.rLanguages
        )

        let actionsViewModel = AlertPresentableViewModel(
            title: title,
            message: nil,
            actions: actions,
            closeAction: closeTitle
        )

        wireframe.present(
            viewModel: actionsViewModel,
            style: .actionSheet,
            from: view
        )
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
        } else {
            let languages = view?.selectedLocale.rLanguages

            let title = R.string.localizable.commonChainAccountMissingTitleFormat(
                chain.name,
                preferredLanguages: languages
            )

            let messages = R.string.localizable.commonChainAccountMissingMessageFormat(
                chain.name,
                preferredLanguages: languages
            )

            let cancelAction = AlertPresentableAction(
                title: R.string.localizable.commonCancel(preferredLanguages: languages),
                style: .destructive
            )

            let addAction = AlertPresentableAction(
                title: R.string.localizable.commonAdd(preferredLanguages: languages)
            ) { [weak self] in
                self?.addAccount(for: chain, wallet: wallet)
            }

            let viewModel = AlertPresentableViewModel(
                title: title,
                message: messages,
                actions: [cancelAction, addAction],
                closeAction: nil
            )

            wireframe.present(viewModel: viewModel, style: .alert, from: view)
        }
    }

    func performAccountAction() {
        wireframe.showAccountsSelection(from: view)
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
    func assetSelection(view _: ChainSelectionViewProtocol, didCompleteWith chainAsset: ChainAsset) {
        interactor.save(chainAsset: chainAsset)
    }
}
