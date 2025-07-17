import Foundation
import Foundation_iOS

final class MythosStkUnstakeConfirmPresenter {
    weak var view: CollatorStkUnstakeConfirmViewProtocol?
    let wireframe: MythosStkUnstakeConfirmWireframeProtocol
    let interactor: MythosStkUnstakeConfirmInteractorInputProtocol

    let chainAsset: ChainAsset
    let selectedAccount: MetaChainAccountResponse
    let selectedCollator: DisplayAddress
    let dataValidatingFactory: MythosStakingValidationFactoryProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let hintViewModelFactory: CollatorStakingHintsViewModelFactoryProtocol
    let logger: LoggerProtocol

    private(set) var fee: ExtrinsicFeeProtocol?
    private(set) var balance: AssetBalance?
    private(set) var price: PriceData?
    private(set) var stakingDetails: MythosStakingDetails?
    private(set) var claimableRewards: MythosStakingClaimableRewards?
    private(set) var delegationIdentities: [AccountId: AccountIdentity]?
    private(set) var stakingDuration: MythosStakingDuration?
    private(set) var maxUnstakingCollators: UInt32?
    private(set) var releaseQueue: MythosStakingPallet.ReleaseQueue?

    private lazy var walletViewModelFactory = WalletAccountViewModelFactory()
    private lazy var displayAddressViewModelFactory = DisplayAddressViewModelFactory()

    init(
        interactor: MythosStkUnstakeConfirmInteractorInputProtocol,
        wireframe: MythosStkUnstakeConfirmWireframeProtocol,
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        selectedCollator: DisplayAddress,
        dataValidatingFactory: MythosStakingValidationFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        hintViewModelFactory: CollatorStakingHintsViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.selectedCollator = selectedCollator
        self.dataValidatingFactory = dataValidatingFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.hintViewModelFactory = hintViewModelFactory
        self.logger = logger

        self.localizationManager = localizationManager
    }

    func getCollatorId() -> AccountId? {
        try? selectedCollator.address.toAccountId(using: chainAsset.chain.chainFormat)
    }

    func unstakingAmount() -> Balance? {
        guard let collatorId = getCollatorId() else {
            return nil
        }

        return stakingDetails?.stakeDistribution[collatorId]?.stake
    }

    func getUnstakingModel() -> MythosStkUnstakeModel? {
        guard
            let collatorId = getCollatorId(),
            let amount = stakingDetails?.stakeDistribution[collatorId]?.stake,
            let claimableRewards else {
            return nil
        }

        return MythosStkUnstakeModel(
            collator: collatorId,
            amount: amount,
            shouldClaimRewards: claimableRewards.shouldClaim
        )
    }

    private func provideAmountViewModel() {
        guard let unstakingAmount = unstakingAmount() else {
            return
        }

        let amountDecimal = unstakingAmount.decimal(assetInfo: chainAsset.assetDisplayInfo)

        let viewModel = balanceViewModelFactory.balanceFromPrice(
            amountDecimal,
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

    private func provideFeeViewModel() {
        let viewModel: BalanceViewModelProtocol? = fee.map { value in
            let amountDecimal = value.amount.decimal(assetInfo: chainAsset.assetDisplayInfo)

            return balanceViewModelFactory.balanceFromPrice(
                amountDecimal,
                priceData: price
            ).value(for: selectedLocale)
        }

        view?.didReceiveFee(viewModel: viewModel)
    }

    private func provideCollatorViewModel() {
        let viewModel = displayAddressViewModelFactory.createViewModel(from: selectedCollator)
        view?.didReceiveCollator(viewModel: viewModel)
    }

    private func provideHintsViewModel() {
        var hints: [String] = []

        if let stakingDuration = stakingDuration {
            let durationHint = hintViewModelFactory.unstakeHint(
                for: stakingDuration.unstaking,
                locale: selectedLocale
            )

            hints.append(durationHint)
        }

        hints.append(hintViewModelFactory.unstakingRewards(for: selectedLocale))
        hints.append(hintViewModelFactory.unstakingRedeem(for: selectedLocale))

        view?.didReceiveHints(viewModel: hints)
    }

    private func presentOptions(for address: AccountAddress) {
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

        guard let model = getUnstakingModel() else {
            return
        }

        interactor.estimateFee(for: model)
    }

    func submitExtrinsic() {
        view?.didStartLoading()

        guard let model = getUnstakingModel() else {
            return
        }

        interactor.submit(model: model)
    }

    func applyCurrentState() {
        provideAmountViewModel()
        provideWalletViewModel()
        provideAccountViewModel()
        provideCollatorViewModel()
        provideHintsViewModel()
    }

    func createValidationRunner() -> DataValidationRunner {
        DataValidationRunner(validators: [
            dataValidatingFactory.has(
                fee: fee,
                locale: selectedLocale,
                onError: { [weak self] in self?.refreshFee() }
            ),
            dataValidatingFactory.notExceedsMaxUnstakingItems(
                unstakingItemsCount: releaseQueue?.count ?? 0,
                maxUnstakingItemsAllowed: maxUnstakingCollators,
                locale: selectedLocale
            ),
            dataValidatingFactory.canPayFeeInPlank(
                balance: balance?.transferable,
                fee: fee,
                asset: chainAsset.assetDisplayInfo,
                locale: selectedLocale
            )
        ])
    }
}

extension MythosStkUnstakeConfirmPresenter: CollatorStkUnstakeConfirmPresenterProtocol {
    func setup() {
        applyCurrentState()

        interactor.setup()

        refreshFee()
    }

    func selectAccount() {
        let chainFormat = chainAsset.chain.chainFormat

        guard let address = try? selectedAccount.chainAccount.accountId.toAddress(using: chainFormat) else {
            return
        }

        presentOptions(for: address)
    }

    func selectCollator() {
        presentOptions(for: selectedCollator.address)
    }

    func confirm() {
        let validationRunner = createValidationRunner()
        validationRunner.runValidation { [weak self] in
            self?.submitExtrinsic()
        }
    }
}

extension MythosStkUnstakeConfirmPresenter: MythosStkUnstakeConfirmInteractorOutputProtocol {
    func didReceiveBalance(_ assetBalance: AssetBalance?) {
        logger.debug("Balance: \(String(describing: balance))")

        balance = assetBalance
    }

    func didReceivePrice(_ price: PriceData?) {
        logger.debug("Price: \(String(describing: price))")

        self.price = price

        provideAmountViewModel()
    }

    func didReceiveStakingDetails(_ details: MythosStakingDetails?) {
        logger.debug("Details: \(String(describing: details))")

        stakingDetails = details

        provideAmountViewModel()
        refreshFee()
    }

    func didReceiveClaimableRewards(_ rewards: MythosStakingClaimableRewards?) {
        logger.debug("Claimable rewards: \(String(describing: rewards))")

        claimableRewards = rewards

        refreshFee()
    }

    func didReceiveStakingDuration(_ duration: MythosStakingDuration) {
        logger.debug("Duration: \(duration)")

        stakingDuration = duration

        provideHintsViewModel()
    }

    func didReceiveMaxUnstakingCollators(_ maxUnstakingCollators: UInt32) {
        logger.debug("Max unstaking collators: \(maxUnstakingCollators)")

        self.maxUnstakingCollators = maxUnstakingCollators
    }

    func didReceiveReleaseQueue(_ releaseQueue: MythosStakingPallet.ReleaseQueue?) {
        logger.debug("Release queue: \(String(describing: releaseQueue))")

        self.releaseQueue = releaseQueue
    }

    func didReceiveFee(_ fee: ExtrinsicFeeProtocol) {
        logger.debug("Fee: \(fee)")

        self.fee = fee

        provideFeeViewModel()
    }

    func didReceiveBaseError(_ error: MythosStkUnstakeInteractorError) {
        logger.error("Error: \(error)")

        switch error {
        case .stakingDurationFailed:
            wireframe.presentRequestStatus(
                on: view,
                locale: selectedLocale
            ) { [weak self] in
                self?.interactor.retryStakingDuration()
            }
        case .feeFailed:
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

extension MythosStkUnstakeConfirmPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            applyCurrentState()
        }
    }
}
