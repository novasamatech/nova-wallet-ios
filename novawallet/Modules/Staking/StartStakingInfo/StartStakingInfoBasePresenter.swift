import Foundation
import SoraFoundation
import BigInt

class StartStakingInfoBasePresenter: StartStakingInfoInteractorOutputProtocol, StartStakingInfoPresenterProtocol {
    weak var view: StartStakingInfoViewProtocol?
    let wireframe: StartStakingInfoWireframeProtocol
    let baseInteractor: StartStakingInfoInteractorInputProtocol
    let startStakingViewModelFactory: StartStakingViewModelFactoryProtocol
    let applicationConfig: ApplicationConfigProtocol
    let logger: LoggerProtocol?

    private(set) var price: PriceData?
    private(set) var chainAsset: ChainAsset?
    private(set) var balanceState: BalanceState?
    private var state: StartStakingStateProtocol?
    private var wallet: MetaAccountModel?

    init(
        interactor: StartStakingInfoInteractorInputProtocol,
        wireframe: StartStakingInfoWireframeProtocol,
        startStakingViewModelFactory: StartStakingViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        applicationConfig: ApplicationConfigProtocol,
        logger: LoggerProtocol?
    ) {
        baseInteractor = interactor
        self.wireframe = wireframe
        self.startStakingViewModelFactory = startStakingViewModelFactory
        self.applicationConfig = applicationConfig
        self.logger = logger
        self.localizationManager = localizationManager
    }

    func provideBalanceModel() {
        guard let chainAsset = chainAsset else {
            return
        }
        switch balanceState {
        case let .assetBalance(balance):
            let viewModel = startStakingViewModelFactory.balance(
                amount: balance.freeInPlank,
                priceData: price,
                chainAsset: chainAsset,
                locale: selectedLocale
            )
            view?.didReceive(balance: viewModel)
        case .noAccount:
            let viewModel = startStakingViewModelFactory.noAccount(chain: chainAsset.chain, locale: selectedLocale)
            view?.didReceive(balance: viewModel)
        case .none:
            break
        }
    }

    func provideViewModel(state: StartStakingStateProtocol) {
        self.state = state

        guard
            let enoughTokensForDirectStaking = enoughTokensForDirectStaking(state: state),
            let chainAsset = chainAsset,
            let eraDuration = state.eraDuration,
            let unstakingTime = state.unstakingTime,
            let nextEraStartTime = state.nextEraStartTime,
            let minStake = state.minStake,
            let maxApy = state.maxApy else {
            return
        }

        let directStakingAmount = enoughTokensForDirectStaking ? state.directStakingMinStake : nil
        let title = startStakingViewModelFactory.earnupModel(
            earnings: maxApy,
            chainAsset: chainAsset,
            locale: selectedLocale
        )
        let wikiUrl = startStakingViewModelFactory.wikiModel(
            url: applicationConfig.novaWikiURL,
            chain: chainAsset.chain,
            locale: selectedLocale
        )
        let termsUrl = startStakingViewModelFactory.termsModel(
            url: applicationConfig.termsURL,
            locale: selectedLocale
        )
        let testnetModel = chainAsset.chain.isTestnet ? startStakingViewModelFactory.testNetworkModel(
            chain: chainAsset.chain,
            locale: selectedLocale
        ) : nil

        let govModel = chainAsset.chain.hasGovernance ? startStakingViewModelFactory.govModel(
            amount: directStakingAmount,
            chainAsset: chainAsset,
            locale: selectedLocale
        ) : nil

        let paragraphs = [
            testnetModel,
            startStakingViewModelFactory.stakeModel(
                minStake: minStake,
                nextEra: nextEraStartTime,
                chainAsset: chainAsset,
                locale: selectedLocale
            ),
            startStakingViewModelFactory.unstakeModel(unstakePeriod: unstakingTime, locale: selectedLocale),
            startStakingViewModelFactory.rewardModel(
                amount: directStakingAmount,
                chainAsset: chainAsset,
                eraDuration: eraDuration,
                locale: selectedLocale
            ),
            govModel,
            startStakingViewModelFactory.recommendationModel(locale: selectedLocale)
        ].compactMap { $0 }

        let model = StartStakingViewModel(
            title: title,
            paragraphs: paragraphs,
            wikiUrl: wikiUrl,
            termsUrl: termsUrl
        )

        view?.didReceive(viewModel: .loaded(value: model))
    }

    private func enoughTokensForDirectStaking(state: StartStakingStateProtocol) -> Bool? {
        guard let balanceState = balanceState else {
            return nil
        }
        guard let minStake = state.minStake else {
            return nil
        }

        switch balanceState {
        case let .assetBalance(assetBalance):
            return assetBalance.freeInPlank >= minStake
        case .noAccount:
            return false
        }
    }

    // MARK: - StartStakingInfoInteractorOutputProtocol

    func didReceive(chainAsset: ChainAsset) {
        self.chainAsset = chainAsset
        provideBalanceModel()
    }

    func didReceive(price: PriceData?) {
        self.price = price
        provideBalanceModel()
    }

    func didReceive(assetBalance: AssetBalance) {
        balanceState = .assetBalance(assetBalance)
        provideBalanceModel()
    }

    func didReceive(wallet: MetaAccountModel, chainAccountId: AccountId?) {
        self.wallet = wallet
        if chainAccountId == nil {
            balanceState = .noAccount
            provideBalanceModel()
        }
    }

    func didReceive(baseError error: BaseStartStakingInfoError) {
        logger?.error("Did receive error: \(error)")

        switch error {
        case .assetBalance, .price:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.baseInteractor.remakeSubscriptions()
            }
        }
    }

    // MARK: - StartStakingInfoPresenterProtocol

    func setup() {
        baseInteractor.setup()
    }

    func startStaking() {
        guard let view = view,
              let chain = chainAsset?.chain,
              let wallet = wallet else {
            return
        }
        switch balanceState {
        case .noAccount:
            let message = R.string.localizable.commonChainAccountMissingMessageFormat(
                chain.name,
                preferredLanguages: selectedLocale.rLanguages
            )

            wireframe.presentAddAccount(
                from: view,
                chainName: chain.name,
                message: message,
                locale: selectedLocale
            ) { [weak self] in
                self?.wireframe.showWalletDetails(
                    from: view,
                    wallet: wallet
                )
            }
        case .assetBalance:
            wireframe.showSetupAmount(from: view)
        case .none:
            break
        }
    }
}

extension StartStakingInfoBasePresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            provideBalanceModel()
            state.map(provideViewModel)
        }
    }
}
