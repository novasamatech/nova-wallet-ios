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
    private var selectedAccount: MetaChainAccountResponse?
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
            let address = try? selectedAccount?.substrateAccountId.toAddress(
                using: chainAsset.chain.chainFormat
            )
        else {
            return
        }

        let viewModel = viewModelFactory.createMainViewModel(
            from: address,
            chainAsset: chainAsset,
            balance: accountInfo?.data.available
        )

        view?.didReceive(viewModel: viewModel)
    }
}

// MARK: - StakingMainPresenterProtocol

extension StakingMainPresenter: StakingMainPresenterProtocol {
    func setup() {
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
        childPresenter?.performMainAction()
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

    func didReceiveSelectedAccount(_ selectedAccount: MetaChainAccountResponse) {
        self.selectedAccount = selectedAccount

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
