import Foundation
import Foundation_iOS

final class MythosStkClaimRewardsPresenter {
    weak var view: MythosStkClaimRewardsViewProtocol?
    let wireframe: MythosStkClaimRewardsWireframeProtocol
    let interactor: MythosStkClaimRewardsInteractorInputProtocol
    let chainAsset: ChainAsset
    let selectedAccount: MetaChainAccountResponse
    let dataValidatorFactory: MythosStakingValidationFactoryProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let logger: LoggerProtocol

    private lazy var walletViewModelFactory = WalletAccountViewModelFactory()
    private lazy var displayAddressViewModelFactory = DisplayAddressViewModelFactory()

    var assetBalance: AssetBalance?
    var claimableRewards: MythosStakingClaimableRewards?
    var price: PriceData?
    var fee: ExtrinsicFeeProtocol?
    var details: MythosStakingDetails?
    var autoCompound: Percent?
    var claimStrategy: StakingClaimRewardsStrategy = .restake

    init(
        interactor: MythosStkClaimRewardsInteractorInputProtocol,
        wireframe: MythosStkClaimRewardsWireframeProtocol,
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        dataValidatorFactory: MythosStakingValidationFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.dataValidatorFactory = dataValidatorFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }
}

private extension MythosStkClaimRewardsPresenter {
    private func getClaimRewardsModel() -> MythosStkClaimRewardsModel? {
        guard let details, let claimableRewards else {
            return nil
        }

        return MythosStkClaimRewardsState(
            details: details,
            claimableRewards: claimableRewards,
            claimStrategy: claimStrategy,
            autoCompound: autoCompound
        ).deriveModel()
    }

    private func provideAmountViewModel() {
        guard let claimableRewards else {
            return
        }

        let rewardsDecimal = claimableRewards.total.decimal(assetInfo: chainAsset.assetDisplayInfo)

        let viewModel = balanceViewModelFactory.balanceFromPrice(
            rewardsDecimal,
            priceData: price
        ).value(for: selectedLocale)

        view?.didReceiveAmount(viewModel: viewModel)
    }

    private func provideWalletViewModel() {
        do {
            let viewModel = try walletViewModelFactory.createDisplayViewModel(from: selectedAccount)
            view?.didReceiveWallet(viewModel: viewModel)
        } catch {
            logger.error("Did receive error: \(error)")
        }
    }

    private func provideAccountViewModel() {
        do {
            let viewModel = try walletViewModelFactory.createViewModel(from: selectedAccount)
            view?.didReceiveAccount(viewModel: viewModel.rawDisplayAddress())
        } catch {
            logger.error("Did receive error: \(error)")
        }
    }

    private func provideFee() {
        let viewModel: BalanceViewModelProtocol? = fee.map { value in
            let amountDecimal = value.amount.decimal(
                assetInfo: chainAsset.assetDisplayInfo
            )

            return balanceViewModelFactory.balanceFromPrice(
                amountDecimal,
                priceData: price
            ).value(for: selectedLocale)
        }

        view?.didReceiveFee(viewModel: viewModel)
    }

    private func provideClaimStrategy() {
        view?.didReceiveClaimStrategy(viewModel: claimStrategy)
    }

    private func updateView() {
        provideAmountViewModel()
        provideWalletViewModel()
        provideAccountViewModel()
        provideFee()
        provideClaimStrategy()
    }

    private func refreshFee() {
        fee = nil
        provideFee()

        guard let model = getClaimRewardsModel() else {
            return
        }

        interactor.estimateFee(for: model)
    }
}

extension MythosStkClaimRewardsPresenter: MythosStkClaimRewardsPresenterProtocol {
    func setup() {
        updateView()

        interactor.setup()

        refreshFee()
    }

    func toggleClaimStrategy() {
        switch claimStrategy {
        case .freeBalance:
            claimStrategy = .restake
        case .restake:
            claimStrategy = .freeBalance
        }

        interactor.save(claimStrategy: claimStrategy)

        refreshFee()
    }

    func confirm() {
        DataValidationRunner(validators: [
            dataValidatorFactory.has(fee: fee, locale: selectedLocale) { [weak self] in
                self?.refreshFee()
            },
            dataValidatorFactory.canPayFeeInPlank(
                balance: assetBalance?.transferable,
                fee: fee,
                asset: chainAsset.assetDisplayInfo,
                locale: selectedLocale
            )
        ]).runValidation { [weak self] in
            guard let model = self?.getClaimRewardsModel() else {
                return
            }

            self?.view?.didStartLoading()

            self?.interactor.submit(model: model)
        }
    }

    func selectAccount() {
        guard
            let address = selectedAccount.chainAccount.toAddress(),
            let view = view else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chainAsset.chain,
            locale: selectedLocale
        )
    }
}

extension MythosStkClaimRewardsPresenter: MythosStkClaimRewardsInteractorOutputProtocol {
    func didReceiveAssetBalance(_ balance: AssetBalance?) {
        logger.debug("Balance: \(String(describing: balance))")

        assetBalance = balance
    }

    func didReceivePrice(_ price: PriceData?) {
        logger.debug("Price: \(String(describing: price))")

        self.price = price

        provideAmountViewModel()
        provideFee()
    }

    func didReceiveClaimableRewards(_ claimableRewards: MythosStakingClaimableRewards) {
        logger.debug("Claimable rewards: \(String(describing: claimableRewards))")

        self.claimableRewards = claimableRewards

        provideAmountViewModel()
        refreshFee()
    }

    func didReceiveStakingDetails(_ stakingDetails: MythosStakingDetails?) {
        logger.debug("Staking details: \(String(describing: stakingDetails))")

        details = stakingDetails

        refreshFee()
    }

    func didReceiveClaimStragegy(_ claimStrategy: StakingClaimRewardsStrategy) {
        logger.debug("Claim strategy: \(claimStrategy)")

        self.claimStrategy = claimStrategy

        provideClaimStrategy()
        refreshFee()
    }

    func didReceiveAutoCompound(_ autoCompound: Percent?) {
        logger.debug("Auto compound: \(String(describing: autoCompound))")

        self.autoCompound = autoCompound

        refreshFee()
    }

    func didReceiveFeeResult(_ result: Result<ExtrinsicFeeProtocol, Error>) {
        switch result {
        case let .success(fee):
            logger.debug("Fee: \(fee)")

            self.fee = fee

            provideFee()
        case let .failure(error):
            logger.error("Fee error: \(error)")

            wireframe.presentFeeStatus(
                on: view,
                locale: selectedLocale
            ) { [weak self] in
                self?.refreshFee()
            }
        }
    }

    func didReceiveSubmissionResult(_ result: Result<ExtrinsicSubmittedModel, Error>) {
        view?.didStopLoading()

        switch result {
        case .success:
            // TODO: MS navigation
            wireframe.presentExtrinsicSubmission(
                from: view,
                completionAction: .dismiss,
                locale: selectedLocale
            )
        case let .failure(error):
            wireframe.handleExtrinsicSigningErrorPresentationElseDefault(
                error,
                view: view,
                closeAction: .dismiss,
                locale: selectedLocale,
                completionClosure: nil
            )
        }
    }
}

extension MythosStkClaimRewardsPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
