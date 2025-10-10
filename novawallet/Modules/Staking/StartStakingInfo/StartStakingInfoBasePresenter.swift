import Foundation
import Foundation_iOS
import BigInt

class StartStakingInfoBasePresenter: StartStakingInfoInteractorOutputProtocol, StartStakingInfoPresenterProtocol {
    weak var view: StartStakingInfoViewProtocol?
    let wireframe: StartStakingInfoWireframeProtocol
    let baseInteractor: StartStakingInfoInteractorInputProtocol
    let startStakingViewModelFactory: StartStakingViewModelFactoryProtocol
    let balanceDerivationFactory: StakingTypeBalanceFactoryProtocol
    let applicationConfig: ApplicationConfigProtocol
    let chainAsset: ChainAsset
    let logger: LoggerProtocol
    let accountManagementFilter: AccountManagementFilterProtocol

    private(set) var price: PriceData?
    private(set) var accountExistense: AccountExistense?
    private var state: StartStakingStateProtocol?
    private var wallet: MetaAccountModel?

    init(
        chainAsset: ChainAsset,
        interactor: StartStakingInfoInteractorInputProtocol,
        wireframe: StartStakingInfoWireframeProtocol,
        startStakingViewModelFactory: StartStakingViewModelFactoryProtocol,
        balanceDerivationFactory: StakingTypeBalanceFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        applicationConfig: ApplicationConfigProtocol,
        accountManagementFilter: AccountManagementFilterProtocol = AccountManagementFilter(),
        logger: LoggerProtocol
    ) {
        self.chainAsset = chainAsset
        baseInteractor = interactor
        self.wireframe = wireframe
        self.startStakingViewModelFactory = startStakingViewModelFactory
        self.balanceDerivationFactory = balanceDerivationFactory
        self.applicationConfig = applicationConfig
        self.accountManagementFilter = accountManagementFilter
        self.logger = logger
        self.localizationManager = localizationManager
    }

    func provideBalanceModel() {
        guard let accountExistense = accountExistense else {
            return
        }

        switch accountExistense {
        case let .assetBalance(balance):
            guard let availableBalance = balanceDerivationFactory.getAvailableBalance(from: balance) else {
                return
            }

            let viewModel = startStakingViewModelFactory.balance(
                amount: availableBalance,
                priceData: price,
                chainAsset: chainAsset,
                locale: selectedLocale
            )
            view?.didReceive(balance: viewModel)
        case .noAccount:
            let viewModel = startStakingViewModelFactory.noAccount(chain: chainAsset.chain, locale: selectedLocale)
            view?.didReceive(balance: viewModel)
        }
    }

    func shouldUpdateEraDuration(for newValue: TimeInterval?, oldValue: TimeInterval?) -> Bool {
        guard let oldValue = oldValue else {
            return true
        }

        guard let newValue = newValue else {
            return false
        }

        if newValue > oldValue {
            return true
        } else {
            return oldValue - newValue > StartStakingInfoConstants.eraDurationReduceThreshold
        }
    }

    // swiftlint:disable:next function_body_length
    func provideViewModel(state: StartStakingStateProtocol) {
        self.state = state

        guard
            let rewardTime = state.rewardTime,
            let unstakingTime = state.unstakingTime,
            let rewardDelay = state.rewardDelay,
            let minStake = state.minStake,
            let maxApy = state.maxApy else {
            return
        }

        let title = startStakingViewModelFactory.earnupModel(
            earnings: maxApy,
            chainAsset: chainAsset,
            locale: selectedLocale
        )
        let wikiUrl = startStakingViewModelFactory.wikiModel(
            url: chainAsset.chain.stakingWiki ?? applicationConfig.websiteURL,
            chainAsset: chainAsset,
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

        let govModel = state.shouldHaveGovInfo ? startStakingViewModelFactory.govModel(
            amount: state.govThresholdAmount,
            chainAsset: chainAsset,
            locale: selectedLocale
        ) : nil

        let paragraphs = [
            testnetModel,
            startStakingViewModelFactory.stakeModel(
                minStake: minStake,
                rewardStartDelay: rewardDelay,
                chainAsset: chainAsset,
                locale: selectedLocale
            ),
            startStakingViewModelFactory.unstakeModel(unstakePeriod: unstakingTime, locale: selectedLocale),
            startStakingViewModelFactory.rewardModel(
                amount: state.rewardsAutoPayoutThresholdAmount,
                chainAsset: chainAsset,
                rewardTimeInterval: rewardTime,
                destination: state.rewardsDestination,
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

    // MARK: - StartStakingInfoInteractorOutputProtocol

    func didReceive(price: PriceData?) {
        self.price = price
        provideBalanceModel()
    }

    func didReceive(assetBalance: AssetBalance) {
        accountExistense = .assetBalance(assetBalance)
        provideBalanceModel()
    }

    func didReceive(wallet: MetaAccountModel, chainAccountId: AccountId?) {
        self.wallet = wallet
        if chainAccountId == nil {
            accountExistense = .noAccount
            provideBalanceModel()
        }
    }

    func didReceive(baseError error: BaseStartStakingInfoError) {
        logger.error("Did receive error: \(error)")

        switch error {
        case .assetBalance, .price, .stakingState:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.baseInteractor.remakeSubscriptions()
            }
        }
    }

    func didReceiveStakingEnabled() {
        wireframe.presentAlreadyHaveStaking(
            from: view,
            networkName: chainAsset.chain.name,
            onClose: { [weak self] in
                self?.wireframe.complete(from: self?.view)
            }, locale: selectedLocale
        )
    }

    // MARK: - StartStakingInfoPresenterProtocol

    func setup() {
        baseInteractor.setup()
    }

    func showNoAccountAlert() {
        guard let view = view,
              let wallet = wallet else {
            return
        }
        if accountManagementFilter.canAddAccount(to: wallet, chain: chainAsset.chain) {
            let message = R.string.localizable.commonChainAccountMissingMessageFormat(
                chainAsset.chain.name,
                preferredLanguages: selectedLocale.rLanguages
            )
            wireframe.presentAddAccount(
                from: view,
                chainName: chainAsset.chain.name,
                message: message,
                locale: selectedLocale
            ) { [weak self] in
                self?.wireframe.showWalletDetails(
                    from: view,
                    wallet: wallet
                )
            }
        } else {
            wireframe.presentNoAccountSupport(
                from: view,
                walletType: wallet.type,
                chainName: chainAsset.chain.name,
                locale: selectedLocale
            )
        }
    }

    func startStaking() {
        guard let view = view,
              let accountExistense = accountExistense else {
            return
        }

        switch accountExistense {
        case .noAccount:
            showNoAccountAlert()
        case .assetBalance:
            wireframe.showSetupAmount(from: view)
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
