import BigInt
import Foundation
import Foundation_iOS

final class SubtensorClaimRewardsPresenter {
    weak var view: SubtensorClaimRewardsViewProtocol?
    let wireframe: SubtensorClaimRewardsWireframeProtocol
    let interactor: SubtensorClaimRewardsInteractorInputProtocol
    let chainAsset: ChainAsset
    let selectedAccount: MetaChainAccountResponse
    let dataValidationFactory: SubtensorStakingValidationFactoryProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let logger: LoggerProtocol

    private lazy var walletViewModelFactory = WalletAccountViewModelFactory()

    private(set) var balance: AssetBalance?
    private(set) var price: PriceData?
    private(set) var claimable: SubtensorRootClaimable?
    private(set) var preflight: SubtensorStakingPreflight?
    private(set) var singleClaimFee: ExtrinsicFeeProtocol?

    init(
        interactor: SubtensorClaimRewardsInteractorInputProtocol,
        wireframe: SubtensorClaimRewardsWireframeProtocol,
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        dataValidationFactory: SubtensorStakingValidationFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.dataValidationFactory = dataValidationFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }
}

private extension SubtensorClaimRewardsPresenter {
    func getClaimState() -> SubtensorClaimRewardsState? {
        guard let claimable, let preflight else {
            return nil
        }

        return SubtensorClaimRewardsState(
            claimable: claimable,
            threshold: preflight.rootClaimableThreshold
        )
    }

    func getTotalFee() -> ExtrinsicFeeProtocol? {
        guard let singleClaimFee, let claimState = getClaimState() else {
            return nil
        }

        return claimState.totalFee(from: singleClaimFee)
    }

    func provideAmountViewModel() {
        guard let claimState = getClaimState() else {
            return
        }

        let claimableDecimal = claimState.eligibleTotal.decimal(
            assetInfo: chainAsset.assetDisplayInfo
        )

        let viewModel = balanceViewModelFactory.balanceFromPrice(
            claimableDecimal,
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
        let viewModel: BalanceViewModelProtocol? = getTotalFee().map { value in
            let amountDecimal = value.amount.decimal(assetInfo: chainAsset.assetDisplayInfo)

            return balanceViewModelFactory.balanceFromPrice(
                amountDecimal,
                priceData: price
            ).value(for: selectedLocale).approximatelyForSubtensorFee()
        }

        view?.didReceiveFee(viewModel: viewModel)
    }

    func providePendingViewModel() {
        guard let claimState = getClaimState(), claimState.pendingTotal > 0 else {
            view?.didReceivePending(viewModel: nil)
            return
        }

        let pendingDecimal = claimState.pendingTotal.decimal(
            assetInfo: chainAsset.assetDisplayInfo
        )

        let viewModel = balanceViewModelFactory.balanceFromPrice(
            pendingDecimal,
            priceData: price
        ).value(for: selectedLocale)

        view?.didReceivePending(viewModel: viewModel)
    }

    func provideHintsViewModel() {
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable

        var hints = [strings.stakingSubtensorClaimRestakeNote()]

        if let claimState = getClaimState(), claimState.pendingTotal > 0 {
            let threshold = formatAmount(claimState.threshold)

            hints.append(strings.stakingSubtensorClaimPendingNote(threshold))
        }

        view?.didReceiveHints(viewModel: hints)
    }

    func formatAmount(_ value: Balance) -> String {
        let decimal = value.decimal(assetInfo: chainAsset.assetDisplayInfo)

        return balanceViewModelFactory.amountFromValue(decimal).value(for: selectedLocale)
    }

    func updateView() {
        provideAmountViewModel()
        providePendingViewModel()
        provideWalletViewModel()
        provideAccountViewModel()
        provideFeeViewModel()
        provideHintsViewModel()
    }

    func refreshFee() {
        singleClaimFee = nil
        provideFeeViewModel()

        guard let claimState = getClaimState(), let hotkey = claimState.eligibleHotkeys.first else {
            return
        }

        interactor.estimateFee(for: .claim(hotkey: hotkey))
    }

    func refreshPreflight() {
        let hotkey = claimable?.previews.first?.hotkey ?? AccountId.zeroAccountId(
            of: chainAsset.chain.accountIdSize
        )

        interactor.refreshPreflight(for: hotkey, netuid: SubtensorStakingPallet.rootNetuid)
    }

    func createSuccessTitle(
        for submission: SubtensorSubmissionModel
    ) -> ExtrinsicSubmissionPresentingParams.Title {
        guard case let .claimed(tao) = submission.outcome, tao > 0 else {
            return .general(selectedLocale)
        }

        let amountDecimal = tao.decimal(assetInfo: chainAsset.assetDisplayInfo)
        let amountString = balanceViewModelFactory.amountFromValue(
            amountDecimal
        ).value(for: selectedLocale)

        let title = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.stakingSubtensorSuccessClaimedFormat(amountString)

        return .preferred(title)
    }
}

extension SubtensorClaimRewardsPresenter: StakingGenericRewardsPresenterProtocol {
    func setup() {
        updateView()

        interactor.setup()

        refreshPreflight()
    }

    func confirm() {
        let totalFee = getTotalFee()

        DataValidationRunner(validators: [
            dataValidationFactory.has(fee: totalFee, locale: selectedLocale) { [weak self] in
                self?.refreshFee()
            },
            dataValidationFactory.claimFeeCoveredByTransferable(
                transferable: balance?.transferable,
                fee: totalFee?.amountForCurrentAccount,
                locale: selectedLocale
            ),
            dataValidationFactory.claimableAtLeastThreshold(
                claimable: getClaimState()?.eligibleTotal,
                threshold: preflight?.rootClaimableThreshold,
                locale: selectedLocale
            )
        ]).runValidation { [weak self] in
            guard let hotkeys = self?.getClaimState()?.eligibleHotkeys, !hotkeys.isEmpty else {
                return
            }

            self?.view?.didStartLoading()

            self?.interactor.submitClaims(for: hotkeys)
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

extension SubtensorClaimRewardsPresenter: SubtensorClaimRewardsInteractorOutputProtocol {
    func didReceiveSubmissionResult(_ result: Result<SubtensorSubmissionModel, Error>) {
        view?.didStopLoading()

        switch result {
        case let .success(submission):
            wireframe.complete(
                on: view,
                sender: submission.submitted.sender,
                title: createSuccessTitle(for: submission)
            )
        case let .failure(error):
            logger.error("Submission error: \(error)")

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
        providePendingViewModel()
        provideFeeViewModel()
    }

    func didReceiveFee(_ fee: ExtrinsicFeeProtocol) {
        logger.debug("Fee: \(fee)")

        singleClaimFee = fee

        provideFeeViewModel()
    }

    func didReceivePositions(_ state: Multistaking.SubtensorStakingState?) {
        logger.debug("Positions: \(String(describing: state))")
    }

    func didReceiveClaimable(_ claimable: SubtensorRootClaimable?) {
        logger.debug("Claimable: \(String(describing: claimable))")

        let hadClaimable = self.claimable != nil

        self.claimable = claimable

        provideAmountViewModel()
        providePendingViewModel()
        provideHintsViewModel()

        if !hadClaimable {
            refreshPreflight()
        }

        if singleClaimFee == nil {
            refreshFee()
        }
    }

    func didReceiveBlockNumber(_ blockNumber: BlockNumber) {
        logger.debug("Block number: \(blockNumber)")
    }

    func didReceiveQuote(_ quote: SubtensorQuote) {
        logger.debug("Quote: \(quote)")
    }

    func didReceivePreflight(_ preflight: SubtensorStakingPreflight) {
        logger.debug("Preflight: \(preflight)")

        self.preflight = preflight

        provideAmountViewModel()
        providePendingViewModel()
        provideHintsViewModel()
        refreshFee()
    }

    func didReceiveExistentialDeposit(_ deposit: Balance) {
        logger.debug("Existential deposit: \(deposit)")
    }

    func didReceiveBaseError(_ error: SubtensorStakingBaseError) {
        logger.error("Error: \(error)")

        switch error {
        case .feeFailed:
            wireframe.presentFeeStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.refreshFee()
            }
        case .preflightFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.refreshPreflight()
            }
        case .quoteFailed:
            break
        }
    }
}

extension SubtensorClaimRewardsPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
