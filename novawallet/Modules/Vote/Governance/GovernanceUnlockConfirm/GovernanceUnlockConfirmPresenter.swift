import Foundation
import BigInt
import Foundation_iOS

final class GovernanceUnlockConfirmPresenter {
    weak var view: GovernanceUnlockConfirmViewProtocol?
    let wireframe: GovernanceUnlockConfirmWireframeProtocol
    let interactor: GovernanceUnlockConfirmInteractorInputProtocol

    let chain: ChainModel
    let selectedAccount: MetaChainAccountResponse
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let lockChangeViewModelFactory: ReferendumLockChangeViewModelFactoryProtocol
    let dataValidatingFactory: GovernanceValidatorFactoryProtocol
    let logger: LoggerProtocol

    private var votingResult: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>
    private var unlockSchedule: GovernanceUnlockSchedule
    private var locks: AssetLocks?
    private var assetBalance: AssetBalance?
    private var blockNumber: BlockNumber
    private var price: PriceData?
    private var fee: ExtrinsicFeeProtocol?

    private lazy var walletDisplayViewModelFactory = WalletAccountViewModelFactory()
    private lazy var addressDisplayViewModelFactory = DisplayAddressViewModelFactory()

    init(
        interactor: GovernanceUnlockConfirmInteractorInputProtocol,
        wireframe: GovernanceUnlockConfirmWireframeProtocol,
        chain: ChainModel,
        selectedAccount: MetaChainAccountResponse,
        initData: GovernanceUnlockConfirmInitData,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        lockChangeViewModelFactory: ReferendumLockChangeViewModelFactoryProtocol,
        dataValidatingFactory: GovernanceValidatorFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chain = chain
        self.selectedAccount = selectedAccount
        votingResult = initData.votingResult
        unlockSchedule = initData.unlockSchedule
        blockNumber = initData.blockNumber
        self.balanceViewModelFactory = balanceViewModelFactory
        self.lockChangeViewModelFactory = lockChangeViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func provideAmountViewModel() {
        let amount = unlockSchedule.availableUnlock(at: blockNumber).amount

        guard
            let precision = chain.utilityAsset()?.displayInfo.assetPrecision,
            let decimalAmount = Decimal.fromSubstrateAmount(amount, precision: precision) else {
            return
        }

        let viewModel = balanceViewModelFactory.balanceFromPrice(
            decimalAmount,
            priceData: price
        ).value(for: selectedLocale)

        view?.didReceiveAmount(viewModel: viewModel)
    }

    private func provideWalletViewModel() {
        guard
            let viewModel = try? walletDisplayViewModelFactory.createDisplayViewModel(
                from: selectedAccount
            ) else {
            return
        }

        view?.didReceiveWallet(viewModel: viewModel.cellViewModel)
    }

    private func provideAccountViewModel() {
        guard let address = selectedAccount.chainAccount.toAddress() else {
            return
        }

        let viewModel = addressDisplayViewModelFactory.createViewModel(from: address)
        view?.didReceiveAccount(viewModel: viewModel)
    }

    private func provideFeeViewModel() {
        if let fee = fee {
            guard let precision = chain.utilityAsset()?.displayInfo.assetPrecision else {
                return
            }

            let feeDecimal = Decimal.fromSubstrateAmount(
                fee.amount,
                precision: precision
            ) ?? 0.0

            let viewModel = balanceViewModelFactory.balanceFromPrice(feeDecimal, priceData: price)
                .value(for: selectedLocale)

            view?.didReceiveFee(viewModel: viewModel)
        } else {
            view?.didReceiveFee(viewModel: nil)
        }
    }

    private func provideChangesViewModels() {
        guard let tracksVoting = votingResult.value else {
            return
        }

        let totalLocked = tracksVoting.totalLocked()
        let unlocking = unlockSchedule.availableUnlock(at: blockNumber).amount
        let remainedLocked = totalLocked > unlocking ? totalLocked - unlocking : 0

        if
            let govViewModel = lockChangeViewModelFactory.createAmountViewModel(
                initLocked: totalLocked,
                resultLocked: remainedLocked,
                locale: selectedLocale
            ) {
            view?.didReceiveLockedAmount(viewModel: govViewModel)
        }

        if
            let assetBalance = assetBalance,
            let locks = locks,
            let transferableViewModel = lockChangeViewModelFactory.createTransferableAmountViewModel(
                resultLocked: remainedLocked,
                balance: assetBalance,
                locks: locks,
                locale: selectedLocale
            ) {
            view?.didReceiveTransferableAmount(viewModel: transferableViewModel)
        }

        if let locks = locks {
            let remainedLocksViewModel = lockChangeViewModelFactory.createRemainedOtherLocksViewModel(
                locks: locks,
                locale: selectedLocale
            )

            view?.didReceiveRemainedLock(viewModel: remainedLocksViewModel)
        } else {
            view?.didReceiveRemainedLock(viewModel: nil)
        }
    }

    private func updateView() {
        provideAmountViewModel()
        provideWalletViewModel()
        provideAccountViewModel()
        provideFeeViewModel()
        provideChangesViewModels()
    }

    private func refreshFee() {
        fee = nil

        provideFeeViewModel()

        let actions = unlockSchedule.availableUnlock(at: blockNumber).actions

        guard !actions.isEmpty else {
            fee = ExtrinsicFee(amount: 0, payer: nil, weight: .zero)

            provideFeeViewModel()

            return
        }

        interactor.estimateFee(for: actions)
    }

    private func refreshUnlockSchedule() {
        guard let tracksVoting = votingResult.value else {
            return
        }

        interactor.refreshUnlockSchedule(for: tracksVoting)
    }
}

extension GovernanceUnlockConfirmPresenter: GovernanceUnlockConfirmPresenterProtocol {
    func setup() {
        updateView()

        interactor.setup()

        refreshFee()
    }

    func confirm() {
        guard let assetInfo = chain.utilityAssetDisplayInfo() else {
            return
        }

        DataValidationRunner(
            validators: [
                dataValidatingFactory.has(fee: fee, locale: selectedLocale) { [weak self] in
                    self?.refreshFee()
                },
                dataValidatingFactory.canPayFeeInPlank(
                    balance: assetBalance?.transferable,
                    fee: fee,
                    asset: assetInfo,
                    locale: selectedLocale
                )
            ]
        ).runValidation { [weak self] in
            guard
                let blockNumber = self?.blockNumber,
                let actions = self?.unlockSchedule.availableUnlock(at: blockNumber).actions,
                !actions.isEmpty else {
                return
            }

            self?.view?.didStartLoading()
            self?.interactor.unlock(using: actions)
        }
    }

    func presentSenderDetails() {
        guard
            let address = try? selectedAccount.chainAccount.accountId.toAddress(using: chain.chainFormat),
            let view = view else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chain,
            locale: selectedLocale
        )
    }
}

extension GovernanceUnlockConfirmPresenter: GovernanceUnlockConfirmInteractorOutputProtocol {
    func didReceiveBalance(_ assetBalance: AssetBalance?) {
        self.assetBalance = assetBalance

        provideChangesViewModels()
    }

    func didReceiveLocks(_ locks: AssetLocks) {
        self.locks = locks

        provideChangesViewModels()
    }

    func didReceiveSubmissionResult(_ result: SubmitIndexedExtrinsicResult) {
        view?.didStopLoading()

        let handlers = MultiExtrinsicResultActions(
            onSuccess: { [weak self] in
                guard let strongSelf = self else {
                    return
                }

                strongSelf.wireframe.presentExtrinsicSubmission(
                    from: strongSelf.view,
                    sender: result.senders().first,
                    completionAction: .dismiss,
                    locale: strongSelf.selectedLocale
                )
            }, onErrorRetry: { [weak self] closure, indexes in
                self?.view?.didStartLoading()

                self?.interactor.retryMultiExtrinsic(
                    for: closure,
                    indexes: indexes
                )
            }, onErrorSkip: { [weak self] in
                self?.wireframe.skip(on: self?.view)
            }
        )

        wireframe.presentMultiExtrinsicStatusFromResult(
            on: view,
            result: result,
            locale: selectedLocale,
            handlers: handlers
        )
    }

    func didReceiveFee(_ fee: ExtrinsicFeeProtocol) {
        self.fee = fee

        provideFeeViewModel()
    }

    func didReceiveError(_ error: GovernanceUnlockConfirmInteractorError) {
        logger.error("Did receive error: \(error)")

        switch error {
        case .locksSubscriptionFailed, .balanceSubscriptionFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.remakeSubscriptions()
            }
        case .feeFetchFailed:
            wireframe.presentFeeStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.refreshFee()
            }
        case let .unlockFailed(internalError):
            view?.didStopLoading()

            wireframe.handleExtrinsicSigningErrorPresentationElseDefault(
                internalError,
                view: view,
                closeAction: .dismiss,
                locale: selectedLocale,
                completionClosure: nil
            )
        }
    }

    func didReceiveVoting(_ result: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>) {
        votingResult = result

        if let tracksVoting = result.value {
            interactor.refreshUnlockSchedule(for: tracksVoting)
        }

        provideChangesViewModels()
    }

    func didReceiveUnlockSchedule(_ schedule: GovernanceUnlockSchedule) {
        if schedule != unlockSchedule {
            unlockSchedule = schedule

            provideChangesViewModels()
            provideAmountViewModel()
            refreshFee()
        }
    }

    func didReceiveBlockNumber(_ block: BlockNumber) {
        blockNumber = block

        provideFeeViewModel()

        provideChangesViewModels()
        provideAmountViewModel()
        refreshUnlockSchedule()
    }

    func didReceiveBlockTime(_: BlockTime) {}

    func didReceivePrice(_ price: PriceData?) {
        self.price = price

        provideAmountViewModel()
    }

    func didReceiveBaseError(_ error: GovernanceUnlockInteractorError) {
        logger.error("Did receive base error: \(error)")

        switch error {
        case .votingSubscriptionFailed, .priceSubscriptionFailed, .blockNumberSubscriptionFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.remakeSubscriptions()
            }
        case .unlockScheduleFetchFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.refreshUnlockSchedule()
            }
        case .blockTimeFetchFailed:
            break
        }
    }
}

extension GovernanceUnlockConfirmPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
