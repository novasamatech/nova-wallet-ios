import Foundation
import Foundation_iOS
import BigInt

final class NPoolsClaimRewardsPresenter {
    weak var view: StakingClaimRewardsViewProtocol?
    let wireframe: NPoolsClaimRewardsWireframeProtocol
    let interactor: NPoolsClaimRewardsInteractorInputProtocol
    let chainAsset: ChainAsset
    let dataValidatorFactory: NominationPoolDataValidatorFactoryProtocol
    let stakingActivity: StakingActivityForValidating
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let selectedAccount: MetaChainAccountResponse
    let logger: LoggerProtocol

    var claimRewardsStrategy: StakingClaimRewardsStrategy = .freeBalance

    private lazy var walletViewModelFactory = WalletAccountViewModelFactory()
    private lazy var displayAddressViewModelFactory = DisplayAddressViewModelFactory()

    var assetBalance: AssetBalance?
    var claimableRewards: BigUInt?
    var price: PriceData?
    var existentialDeposit: BigUInt?
    var fee: ExtrinsicFeeProtocol?
    var needsMigration: Bool?

    init(
        interactor: NPoolsClaimRewardsInteractorInputProtocol,
        wireframe: NPoolsClaimRewardsWireframeProtocol,
        selectedAccount: MetaChainAccountResponse,
        chainAsset: ChainAsset,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dataValidatorFactory: NominationPoolDataValidatorFactoryProtocol,
        stakingActivity: StakingActivityForValidating,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.selectedAccount = selectedAccount
        self.chainAsset = chainAsset
        self.balanceViewModelFactory = balanceViewModelFactory
        self.dataValidatorFactory = dataValidatorFactory
        self.stakingActivity = stakingActivity
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func provideAmountViewModel() {
        guard let claimableRewards = claimableRewards?.decimal(precision: chainAsset.asset.precision) else {
            return
        }

        let viewModel = balanceViewModelFactory.balanceFromPrice(
            claimableRewards,
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
        let viewModel: BalanceViewModelProtocol? = fee.flatMap { value in
            guard let amountDecimal = Decimal.fromSubstrateAmount(
                value.amount,
                precision: chainAsset.assetDisplayInfo.assetPrecision
            ) else {
                return nil
            }

            return balanceViewModelFactory.balanceFromPrice(
                amountDecimal,
                priceData: price
            ).value(for: selectedLocale)
        }

        view?.didReceiveFee(viewModel: viewModel)
    }

    private func provideClaimStrategy() {
        view?.didReceiveClaimStrategy(viewModel: claimRewardsStrategy)
    }

    private func updateView() {
        provideAmountViewModel()
        provideWalletViewModel()
        provideAccountViewModel()
        provideFee()
        provideClaimStrategy()
    }

    private func refreshFee() {
        guard let needsMigration else {
            return
        }

        fee = nil
        provideFee()

        interactor.estimateFee(for: claimRewardsStrategy, needsMigration: needsMigration)
    }
}

extension NPoolsClaimRewardsPresenter: StakingClaimRewardsPresenterProtocol {
    func setup() {
        updateView()

        interactor.setup()

        refreshFee()
    }

    func confirm() {
        DataValidationRunner(validators: [
            dataValidatorFactory.has(fee: fee, locale: selectedLocale) { [weak self] in
                self?.refreshFee()
            },
            dataValidatorFactory.canMigrateIfNeeded(
                needsMigration: needsMigration,
                stakingActivity: stakingActivity,
                onProgress: .init(
                    willStart: { [weak self] in
                        self?.view?.didStartLoading()
                    },
                    didComplete: { [weak self] _ in
                        self?.view?.didStopLoading()
                    }
                ),
                locale: selectedLocale
            ),
            dataValidatorFactory.canPayFeeInPlank(
                balance: assetBalance?.transferable,
                fee: fee,
                asset: chainAsset.assetDisplayInfo,
                locale: selectedLocale
            ),
            dataValidatorFactory.notViolatingMinBalancePaying(
                fee: fee,
                total: assetBalance?.balanceCountingEd,
                minBalance: existentialDeposit,
                asset: chainAsset.assetDisplayInfo,
                locale: selectedLocale
            ),
            dataValidatorFactory.hasProfitAfterClaim(
                rewards: claimableRewards,
                fee: fee,
                chainAsset: chainAsset,
                locale: selectedLocale
            )
        ]).runValidation { [weak self] in
            guard
                let claimRewardsStrategy = self?.claimRewardsStrategy,
                let needsMigration = self?.needsMigration else {
                return
            }

            self?.view?.didStartLoading()

            self?.interactor.submit(for: claimRewardsStrategy, needsMigration: needsMigration)
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

    func toggleClaimStrategy() {
        switch claimRewardsStrategy {
        case .freeBalance:
            claimRewardsStrategy = .restake
        case .restake:
            claimRewardsStrategy = .freeBalance
        }

        refreshFee()
    }
}

extension NPoolsClaimRewardsPresenter: NPoolsClaimRewardsInteractorOutputProtocol {
    func didReceive(assetBalance: AssetBalance?) {
        logger.debug("Asset balance: \(String(describing: assetBalance))")

        self.assetBalance = assetBalance
    }

    func didReceive(claimableRewards: BigUInt?) {
        logger.debug("Claimable rewards: \(String(describing: claimableRewards))")

        self.claimableRewards = claimableRewards

        provideAmountViewModel()
    }

    func didReceive(price: PriceData?) {
        logger.debug("Price: \(String(describing: price))")

        self.price = price

        provideAmountViewModel()
        provideFee()
    }

    func didReceive(fee: ExtrinsicFeeProtocol) {
        logger.debug("Fee: \(String(describing: fee))")

        self.fee = fee

        provideFee()
    }

    func didReceive(existentialDeposit: BigUInt?) {
        logger.debug("Existential deposit: \(String(existentialDeposit ?? 0))")

        self.existentialDeposit = existentialDeposit
    }

    func didReceive(submissionResult: Result<ExtrinsicSubmittedModel, Error>) {
        view?.didStopLoading()

        switch submissionResult {
        case let .success(model):
            // TODO: Fix MS navigation
            wireframe.presentExtrinsicSubmission(
                from: view,
                sender: model.sender,
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

    func didReceive(needsMigration: Bool) {
        logger.debug("Needs migration: \(needsMigration)")

        self.needsMigration = needsMigration

        refreshFee()
    }

    func didReceive(error: NPoolsClaimRewardsError) {
        logger.error("Error: \(error)")

        switch error {
        case .subscription:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.remakeSubscriptions()
            }
        case .fee:
            wireframe.presentFeeStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.refreshFee()
            }
        case .existentialDeposit:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.retryExistentialDeposit()
            }
        }
    }
}

extension NPoolsClaimRewardsPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
