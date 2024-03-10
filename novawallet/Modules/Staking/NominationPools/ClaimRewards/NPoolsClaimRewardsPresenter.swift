import Foundation
import SoraFoundation
import BigInt

final class NPoolsClaimRewardsPresenter {
    weak var view: NPoolsClaimRewardsViewProtocol?
    let wireframe: NPoolsClaimRewardsWireframeProtocol
    let interactor: NPoolsClaimRewardsInteractorInputProtocol
    let chainAsset: ChainAsset
    let dataValidatorFactory: NominationPoolDataValidatorFactoryProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let selectedAccount: MetaChainAccountResponse
    let logger: LoggerProtocol

    var claimRewardsStrategy: NominationPools.ClaimRewardsStrategy = .freeBalance

    private lazy var walletViewModelFactory = WalletAccountViewModelFactory()
    private lazy var displayAddressViewModelFactory = DisplayAddressViewModelFactory()

    var assetBalance: AssetBalance?
    var claimableRewards: BigUInt?
    var price: PriceData?
    var existentialDeposit: BigUInt?
    var fee: ExtrinsicFeeProtocol?

    init(
        interactor: NPoolsClaimRewardsInteractorInputProtocol,
        wireframe: NPoolsClaimRewardsWireframeProtocol,
        selectedAccount: MetaChainAccountResponse,
        chainAsset: ChainAsset,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dataValidatorFactory: NominationPoolDataValidatorFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.selectedAccount = selectedAccount
        self.chainAsset = chainAsset
        self.balanceViewModelFactory = balanceViewModelFactory
        self.dataValidatorFactory = dataValidatorFactory
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
        fee = nil
        provideFee()

        interactor.estimateFee(for: claimRewardsStrategy)
    }
}

extension NPoolsClaimRewardsPresenter: NPoolsClaimRewardsPresenterProtocol {
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
            guard let claimRewardsStrategy = self?.claimRewardsStrategy else {
                return
            }

            self?.view?.didStartLoading()

            self?.interactor.submit(for: claimRewardsStrategy)
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

    func didReceive(submissionResult: Result<String, Error>) {
        view?.didStopLoading()

        switch submissionResult {
        case .success:
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
