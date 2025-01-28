import Foundation
import SoraFoundation

final class MythosStkClaimRewardsPresenter {
    weak var view: StakingGenericRewardsViewProtocol?
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
    var existentialDeposit: Balance?
    var fee: ExtrinsicFeeProtocol?

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

    private func updateView() {
        provideAmountViewModel()
        provideWalletViewModel()
        provideAccountViewModel()
        provideFee()
    }

    private func refreshFee() {
        fee = nil
        provideFee()

        interactor.estimateFee()
    }
}

extension MythosStkClaimRewardsPresenter: StakingGenericRewardsPresenterProtocol {
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
            )
        ]).runValidation { [weak self] in
            self?.view?.didStartLoading()

            self?.interactor.submit()
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
    }

    func didReceive(existentialDeposit: Balance?) {
        logger.debug("Existential deposit: \(String(describing: existentialDeposit))")

        self.existentialDeposit = existentialDeposit
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

    func didReceiveSubmissionResult(_ result: Result<String, Error>) {
        view?.didStopLoading()

        switch result {
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
}

extension MythosStkClaimRewardsPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
