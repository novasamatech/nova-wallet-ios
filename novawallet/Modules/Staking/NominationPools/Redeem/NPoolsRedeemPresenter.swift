import Foundation
import Foundation_iOS
import BigInt

final class NPoolsRedeemPresenter {
    weak var view: NPoolsRedeemViewProtocol?
    let wireframe: NPoolsRedeemWireframeProtocol
    let interactor: NPoolsRedeemInteractorInputProtocol
    let chainAsset: ChainAsset
    let dataValidatorFactory: NominationPoolDataValidatorFactoryProtocol
    let stakingActivity: StakingActivityForValidating

    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let selectedAccount: MetaChainAccountResponse
    let logger: LoggerProtocol

    private lazy var walletViewModelFactory = WalletAccountViewModelFactory()
    private lazy var displayAddressViewModelFactory = DisplayAddressViewModelFactory()

    var assetBalance: AssetBalance?
    var poolMember: NominationPools.PoolMember?
    var subPools: NominationPools.SubPools?
    var activeEra: ActiveEraInfo?
    var existentialDeposit: BigUInt?
    var price: PriceData?
    var fee: ExtrinsicFeeProtocol?
    var needsMigration: Bool?

    init(
        interactor: NPoolsRedeemInteractorInputProtocol,
        wireframe: NPoolsRedeemWireframeProtocol,
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

    private func getRedeemableAmount() -> BigUInt? {
        guard
            let subPools = subPools,
            let poolMember = poolMember,
            let era = activeEra?.index else {
            return nil
        }

        return subPools.redeemableBalance(for: poolMember, in: era)
    }

    private func provideAmountViewModel() {
        guard let amount = getRedeemableAmount()?.decimal(precision: chainAsset.asset.precision) else {
            return
        }

        let viewModel = balanceViewModelFactory.balanceFromPrice(
            amount,
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
        let viewModel: BalanceViewModelProtocol? = fee.flatMap { fee in
            guard let amountDecimal = Decimal.fromSubstrateAmount(
                fee.amount,
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

    private func refreshFee() {
        guard let needsMigration else {
            return
        }

        interactor.estimateFee(needsMigration: needsMigration)
    }

    func updateView() {
        provideAmountViewModel()
        provideWalletViewModel()
        provideAccountViewModel()
        provideFee()
    }
}

extension NPoolsRedeemPresenter: NPoolsRedeemPresenterProtocol {
    func setup() {
        updateView()

        interactor.setup()
    }

    func confirm() {
        DataValidationRunner(validators: [
            dataValidatorFactory.has(
                fee: fee,
                locale: selectedLocale
            ) { [weak self] in
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
            )
        ]).runValidation { [weak self] in
            guard let needsMigration = self?.needsMigration else {
                return
            }

            self?.view?.didStartLoading()
            self?.interactor.submit(needsMigration: needsMigration)
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

extension NPoolsRedeemPresenter: NPoolsRedeemInteractorOutputProtocol {
    func didReceive(assetBalance: AssetBalance?) {
        logger.debug("Asset balance: \(String(describing: assetBalance))")

        self.assetBalance = assetBalance
    }

    func didReceive(poolMember: NominationPools.PoolMember?) {
        logger.debug("Pool member: \(String(describing: assetBalance))")

        self.poolMember = poolMember

        provideAmountViewModel()
    }

    func didReceive(subPools: NominationPools.SubPools?) {
        logger.debug("SubPools: \(String(describing: assetBalance))")

        self.subPools = subPools

        provideAmountViewModel()
    }

    func didReceive(activeEra: ActiveEraInfo?) {
        logger.debug("Active era: \(String(describing: assetBalance))")

        self.activeEra = activeEra

        provideAmountViewModel()
    }

    func didReceive(price: PriceData?) {
        logger.debug("Price: \(String(describing: assetBalance))")

        self.price = price

        provideAmountViewModel()
        provideFee()
    }

    func didReceive(existentialDeposit: BigUInt?) {
        logger.debug("Existential deposit: \(String(existentialDeposit ?? 0))")

        self.existentialDeposit = existentialDeposit
    }

    func didReceive(fee: ExtrinsicFeeProtocol) {
        logger.debug("Fee: \(fee)")

        self.fee = fee

        provideFee()
    }

    func didReceive(submissionResult: Result<ExtrinsicSubmittedModel, Error>) {
        view?.didStopLoading()

        switch submissionResult {
        case let .success(model):
            let totalPoints = poolMember?.points ?? 0
            let willHaveStaking = totalPoints > 0 || (poolMember?.unbondingEras ?? []).count > 1
            let action: ExtrinsicSubmissionPresentingAction = willHaveStaking ? .dismiss : .popBaseAndDismiss

            // TODO: Fix MS navigation
            wireframe.presentExtrinsicSubmission(
                from: view,
                sender: model.sender,
                completionAction: action,
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

    func didReceive(error: NPoolsRedeemError) {
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

extension NPoolsRedeemPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
