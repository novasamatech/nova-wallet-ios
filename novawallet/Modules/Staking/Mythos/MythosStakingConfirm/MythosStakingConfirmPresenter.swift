import Foundation
import Foundation_iOS

final class MythosStakingConfirmPresenter {
    weak var view: CollatorStakingConfirmViewProtocol?
    let wireframe: MythosStakingConfirmWireframeProtocol
    let interactor: MythosStakingConfirmInteractorInputProtocol

    let selectedAccount: MetaChainAccountResponse
    let chainAsset: ChainAsset
    let model: MythosStakeModel
    let logger: LoggerProtocol
    let collator: DisplayAddress
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let dataValidationFactory: MythosStakingValidationFactoryProtocol

    private(set) var balance: AssetBalance?
    private(set) var frozenBalance: MythosStakingFrozenBalance?
    private(set) var stakingDetails: MythosStakingDetails?
    private(set) var price: PriceData?
    private(set) var fee: ExtrinsicFeeProtocol?
    private(set) var minStake: Balance?
    private(set) var maxCollatorsPerStaker: UInt32?
    private(set) var claimableRewards: MythosStakingClaimableRewards?
    private(set) var currentBlock: BlockNumber?

    private lazy var walletViewModelFactory = WalletAccountViewModelFactory()
    private lazy var displayAddressViewModelFactory = DisplayAddressViewModelFactory()

    init(
        interactor: MythosStakingConfirmInteractorInputProtocol,
        wireframe: MythosStakingConfirmWireframeProtocol,
        selectedAccount: MetaChainAccountResponse,
        chainAsset: ChainAsset,
        model: MythosStakingConfirmModel,
        dataValidationFactory: MythosStakingValidationFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.selectedAccount = selectedAccount
        self.chainAsset = chainAsset
        self.model = model.stakeModel
        self.dataValidationFactory = dataValidationFactory
        stakingDetails = model.stakingDetails
        collator = model.collator
        self.balanceViewModelFactory = balanceViewModelFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }
}

private extension MythosStakingConfirmPresenter {
    func getTransactionModel() -> MythosStakeTransactionModel? {
        guard let claimableRewards else {
            return nil
        }

        return MythosStakeTransactionModel(
            input: model,
            shouldClaimRewards: claimableRewards.shouldClaim
        )
    }

    func provideAmountViewModel() {
        let viewModel = balanceViewModelFactory.balanceFromPrice(
            model.amount.toStake.decimal(assetInfo: chainAsset.assetDisplayInfo),
            priceData: price
        ).value(for: selectedLocale)

        view?.didReceiveAmount(viewModel: viewModel)
    }

    func provideWalletViewModel() {
        do {
            let viewModel = try walletViewModelFactory.createDisplayViewModel(from: selectedAccount)
            view?.didReceiveWallet(viewModel: viewModel)
        } catch {
            logger.error("Did receive error: \(error)")
        }
    }

    func provideAccountViewModel() {
        do {
            let viewModel = try walletViewModelFactory.createViewModel(from: selectedAccount)
            view?.didReceiveAccount(viewModel: viewModel.rawDisplayAddress())
        } catch {
            logger.error("Did receive error: \(error)")
        }
    }

    func provideFeeViewModel() {
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

    func provideCollatorViewModel() {
        let viewModel = displayAddressViewModelFactory.createViewModel(from: collator)
        view?.didReceiveCollator(viewModel: viewModel)
    }

    func provideHintsViewModel() {
        if stakingDetails != nil {
            provideStakeMoreHintsViewModel()
        } else {
            provideStartStakingHintsViewModel()
        }
    }

    func presentOptions(for address: AccountAddress) {
        guard let view = view else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chainAsset.chain,
            locale: selectedLocale
        )
    }

    func refreshFee() {
        fee = nil

        provideFeeViewModel()

        guard let transactionModel = getTransactionModel() else {
            return
        }

        interactor.estimateFee(with: transactionModel)
    }

    func submitExtrinsic() {
        guard let transactionModel = getTransactionModel() else {
            return
        }

        view?.didStartLoading()

        interactor.submit(model: transactionModel)
    }

    func applyCurrentState() {
        provideAmountViewModel()
        provideWalletViewModel()
        provideAccountViewModel()
        provideFeeViewModel()
        provideCollatorViewModel()
        provideHintsViewModel()
    }

    func getValidationDependencies() -> MythosStakePresenterValidatingDep {
        let allowedAmount = MythosStakingBalanceState(
            balance: balance,
            frozenBalance: frozenBalance,
            stakingDetails: stakingDetails,
            currentBlock: currentBlock
        )?.stakableAmount()

        return MythosStakePresenterValidatingDep(
            inputAmount: model.amount.toStake.decimal(assetInfo: chainAsset.assetDisplayInfo),
            allowedAmount: allowedAmount,
            balance: balance,
            minStake: minStake,
            stakingDetails: stakingDetails,
            selectedCollator: model.collator,
            fee: fee,
            maxCollatorsPerStaker: maxCollatorsPerStaker,
            assetDisplayInfo: chainAsset.assetDisplayInfo,
            onFeeRefresh: { [weak self] in
                self?.refreshFee()
            }
        )
    }
}

extension MythosStakingConfirmPresenter: CollatorStakingConfirmPresenterProtocol {
    func setup() {
        applyCurrentState()

        interactor.setup()

        refreshFee()
    }

    func selectAccount() {
        guard let address = selectedAccount.chainAccount.toAddress() else {
            return
        }

        presentOptions(for: address)
    }

    func selectCollator() {
        presentOptions(for: collator.address)
    }

    func confirm() {
        let onSuccess: () -> Void = { [weak self] in
            self?.submitExtrinsic()
        }

        if stakingDetails != nil {
            validateStakeMore(
                for: getValidationDependencies(),
                dataValidationFactory: dataValidationFactory,
                selectedLocale: selectedLocale,
                onSuccess: onSuccess
            )
        } else {
            validateStartStaking(
                for: getValidationDependencies(),
                dataValidationFactory: dataValidationFactory,
                selectedLocale: selectedLocale,
                onSuccess: onSuccess
            )
        }
    }
}

extension MythosStakingConfirmPresenter: MythosStakingConfirmInteractorOutputProtocol {
    func didReceiveSubmissionResult(_ result: Result<ExtrinsicSubmittedModel, Error>) {
        view?.didStopLoading()

        switch result {
        case .success:
            // TODO: MS navigation
            wireframe.complete(on: view, locale: selectedLocale)
        case let .failure(error):
            logger.error("Submission error: \(error)")

            applyCurrentState()
            refreshFee()

            wireframe.handleExtrinsicSigningErrorPresentationElseDefault(
                error,
                view: view,
                closeAction: .dismiss,
                locale: selectedLocale,
                completionClosure: nil
            )
        }
    }

    func didReceiveAssetBalance(_ balance: AssetBalance?) {
        logger.debug("Balance: \(String(describing: balance))")

        self.balance = balance
    }

    func didReceivePrice(_ priceData: PriceData?) {
        logger.debug("Price: \(String(describing: priceData))")

        price = priceData

        provideAmountViewModel()
        provideFeeViewModel()
    }

    func didReceiveFee(_ fee: ExtrinsicFeeProtocol) {
        logger.debug("Fee: \(fee)")

        self.fee = fee

        provideFeeViewModel()
    }

    func didReceiveMinStakeAmount(_ amount: Balance) {
        logger.debug("Min stake: \(amount)")

        minStake = amount
    }

    func didReceiveMaxCollatorsPerStaker(_ maxCollatorsPerStaker: UInt32) {
        logger.debug("Max collators per staker: \(maxCollatorsPerStaker)")

        self.maxCollatorsPerStaker = maxCollatorsPerStaker
    }

    func didReceiveDetails(_ details: MythosStakingDetails?) {
        logger.debug("Staking details: \(String(describing: details))")

        stakingDetails = details
    }

    func didReceiveClaimableRewards(_ claimableRewards: MythosStakingClaimableRewards?) {
        logger.debug("Claimable rewards: \(String(describing: claimableRewards))")

        self.claimableRewards = claimableRewards

        refreshFee()
    }

    func didReceiveBlockNumber(_ blockNumber: BlockNumber) {
        logger.debug("Block number: \(blockNumber)")

        currentBlock = blockNumber
    }

    func didReceiveFrozenBalance(_ frozenBalance: MythosStakingFrozenBalance) {
        logger.debug("Frozen balance: \(frozenBalance)")

        self.frozenBalance = frozenBalance
    }

    func didReceiveBaseError(_ error: MythosStakingBaseError) {
        logger.debug("Error: \(error)")

        switch error {
        case .feeFailed:
            wireframe.presentFeeStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.refreshFee()
            }
        }
    }
}

extension MythosStakingConfirmPresenter: MythosStakePresenterValidating {}

extension MythosStakingConfirmPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideAmountViewModel()
            provideFeeViewModel()
            provideHintsViewModel()
        }
    }
}
