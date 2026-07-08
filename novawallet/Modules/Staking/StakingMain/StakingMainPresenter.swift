import Foundation
import Foundation_iOS
import BigInt

final class StakingMainPresenter {
    weak var view: StakingMainViewProtocol?
    let interactor: StakingMainInteractorInputProtocol
    let wireframe: StakingMainWireframeProtocol

    let childPresenterFactory: StakingMainPresenterFactoryProtocol
    let viewModelFactory: StakingMainViewModelFactoryProtocol
    let ahmViewModelFactory: AHMInfoViewModelFactoryProtocol
    let noticesProvider: StakingNoticesProviding
    let stakingOption: Multistaking.ChainAssetOption
    let localizationManager: LocalizationManagerProtocol
    let logger: LoggerProtocol?

    private var ahmInfo: AHMFullInfo?
    private var childPresenter: StakingMainChildPresenterProtocol?
    private var period: StakingRewardFiltersPeriod?

    init(
        interactor: StakingMainInteractorInputProtocol,
        wireframe: StakingMainWireframeProtocol,
        stakingOption: Multistaking.ChainAssetOption,
        noticesProvider: StakingNoticesProviding,
        childPresenterFactory: StakingMainPresenterFactoryProtocol,
        viewModelFactory: StakingMainViewModelFactoryProtocol,
        ahmViewModelFactory: AHMInfoViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol?
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.stakingOption = stakingOption
        self.noticesProvider = noticesProvider
        self.childPresenterFactory = childPresenterFactory
        self.viewModelFactory = viewModelFactory
        self.ahmViewModelFactory = ahmViewModelFactory
        self.localizationManager = localizationManager
        self.logger = logger
    }
}

// MARK: - Private

private extension StakingMainPresenter {
    func provideMainViewModel() {
        let viewModel = viewModelFactory.createMainViewModel(chainAsset: stakingOption.chainAsset)

        view?.didReceive(viewModel: viewModel)
    }

    func provideNoticeModel() {
        let chainId = stakingOption.chainAsset.chain.chainId
        let noticeModel: StakingNoticeBlockView.Model? = noticesProvider.notice(for: chainId).map {
            StakingNoticeBlockView.Model(
                severity: $0.severity == .critical ? .critical : .info,
                title: $0.shortText,
                body: $0.longText
            )
        }
        view?.didReceiveNotice(noticeModel)
    }

    func provideAHMAlertModel() {
        let ahmAlertModel: InlinableAlertView.Model? = if let ahmInfo {
            ahmViewModelFactory.createStakingDetailsAlertViewModel(
                info: ahmInfo,
                locale: localizationManager.selectedLocale
            )
        } else {
            nil
        }

        view?.didReceiveAHMAlert(viewModel: ahmAlertModel)
    }
}

// MARK: - StakingMainPresenterProtocol

extension StakingMainPresenter: StakingMainPresenterProtocol {
    func setup() {
        // setup default view state
        view?.didReceiveStakingState(viewModel: .undefined)

        provideMainViewModel()
        provideNoticeModel()

        if childPresenter == nil, let view = view {
            childPresenter = childPresenterFactory.createPresenter(
                for: stakingOption,
                view: view
            )

            childPresenter?.setup()
        }

        interactor.setup()
    }

    func performRedeemAction() {
        childPresenter?.performRedeemAction()
    }

    func performRebondAction() {
        childPresenter?.performRebondAction()
    }

    func performClaimRewards() {
        childPresenter?.performClaimRewards()
    }

    func networkInfoViewDidChangeExpansion(isExpanded: Bool) {
        interactor.saveNetworkInfoViewExpansion(isExpanded: isExpanded)
    }

    func performManageAction(_ action: StakingManageOption) {
        childPresenter?.performManageAction(action)
    }

    func performAlertAction(_ alert: StakingAlert) {
        childPresenter?.performAlertAction(alert)
    }

    func selectPeriod() {
        wireframe.showPeriodSelection(
            from: view,
            initialState: period,
            delegate: self
        ) { [weak self] in
            self?.view?.didEditRewardFilters()
        }
    }

    func handleAHMAlertClose() {
        interactor.closeAHMAlert()
    }

    func handleAHMAlertLearnMore() {
        guard let view, let ahmInfo else { return }

        wireframe.showWeb(
            url: ahmInfo.info.wikiURL,
            from: view,
            style: .automatic
        )
    }
}

// MARK: - StakingMainInteractorOutputProtocol

extension StakingMainPresenter: StakingMainInteractorOutputProtocol {
    func didReceiveExpansion(_ isExpanded: Bool) {
        view?.expandNetworkInfoView(isExpanded)
    }

    func didReceiveRewardFilter(_ period: StakingRewardFiltersPeriod) {
        self.period = period
        childPresenter?.selectPeriod(period)
    }

    func didReceiveAHMInfo(_ ahmInfo: AHMFullInfo?) {
        guard self.ahmInfo != ahmInfo else { return }

        self.ahmInfo = ahmInfo

        provideAHMAlertModel()
    }

    func didReceiveNoticesUpdate() {
        provideNoticeModel()
    }
}

// MARK: - StakingRewardFiltersDelegate

extension StakingMainPresenter: StakingRewardFiltersDelegate {
    func stackingRewardFilter(didSelectFilter filter: StakingRewardFiltersPeriod) {
        interactor.save(filter: filter)
    }
}
