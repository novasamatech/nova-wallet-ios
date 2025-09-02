import Foundation
import BigInt
import Foundation_iOS

final class ParaStkYieldBoostStartPresenter {
    weak var view: ParaStkYieldBoostStartViewProtocol?
    let wireframe: ParaStkYieldBoostStartWireframeProtocol
    let interactor: ParaStkYieldBoostStartInteractorInputProtocol

    let chainAsset: ChainAsset
    let selectedAccount: MetaChainAccountResponse
    let confirmModel: ParaStkYieldBoostConfirmModel
    let dataValidatingFactory: ParaStkYieldBoostValidatorFactoryProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let logger: LoggerProtocol

    private(set) var yieldBoostTasks: [ParaStkYieldBoostState.Task]?
    private(set) var executionFee: BigUInt?
    private(set) var extrinsicFee: ExtrinsicFeeProtocol?
    private(set) var executionTime: AutomationTime.UnixTime?
    private(set) var balance: AssetBalance?
    private(set) var price: PriceData?

    private lazy var walletDisplayViewModelFactory = WalletAccountViewModelFactory()
    private lazy var addressDisplayViewModelFactory = DisplayAddressViewModelFactory()

    init(
        interactor: ParaStkYieldBoostStartInteractorInputProtocol,
        wireframe: ParaStkYieldBoostStartWireframeProtocol,
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        confirmModel: ParaStkYieldBoostConfirmModel,
        dataValidatingFactory: ParaStkYieldBoostValidatorFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.confirmModel = confirmModel
        self.dataValidatingFactory = dataValidatingFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }

    func refreshFee() {
        executionFee = nil
        extrinsicFee = nil

        if
            let executionTime = executionTime,
            let accountMinimum = confirmModel.accountMinimum.toSubstrateAmount(
                precision: chainAsset.assetDisplayInfo.assetPrecision
            ) {
            let cancellingTaskIds = yieldBoostTasks?.map(\.taskId)

            interactor.estimateScheduleAutocompoundFee(
                for: confirmModel.collator,
                initTime: executionTime,
                frequency: AutomationTime.Seconds(TimeInterval(confirmModel.period).secondsFromDays),
                accountMinimum: accountMinimum,
                cancellingTaskIds: Set(cancellingTaskIds ?? [])
            )
        }

        interactor.estimateTaskExecutionFee()
    }

    func performSubmition() {
        if
            let executionTime = executionTime,
            let accountMinimum = confirmModel.accountMinimum.toSubstrateAmount(
                precision: chainAsset.assetDisplayInfo.assetPrecision
            ) {
            let cancellingTaskIds = yieldBoostTasks?.map(\.taskId)

            view?.didStartLoading()

            interactor.schedule(
                for: confirmModel.collator,
                initTime: executionTime,
                frequency: AutomationTime.Seconds(TimeInterval(confirmModel.period).secondsFromDays),
                accountMinimum: accountMinimum,
                cancellingTaskIds: Set(cancellingTaskIds ?? [])
            )
        }
    }

    func refreshExecutionTime() {
        executionTime = nil

        interactor.fetchTaskExecutionTime(for: confirmModel.period)
    }

    func providePeriod() {
        view?.didReceivePeriod(viewModel: confirmModel.period)
    }

    func provideThreshold() {
        let amount = balanceViewModelFactory.amountFromValue(confirmModel.accountMinimum).value(for: selectedLocale)
        view?.didReceiveThreshold(viewModel: amount)
    }

    func provideWalletViewModel() {
        guard let viewModel = try? walletDisplayViewModelFactory.createDisplayViewModel(from: selectedAccount) else {
            return
        }

        view?.didReceiveWallet(viewModel: viewModel.cellViewModel)
    }

    private func provideAccountViewModel() {
        guard let address = selectedAccount.chainAccount.toAddress() else {
            return
        }

        let viewModel = addressDisplayViewModelFactory.createViewModel(from: address)
        view?.didReceiveSender(viewModel: viewModel)
    }

    private func provideCollatorViewModel() {
        guard let address = try? confirmModel.collator.toAddress(using: chainAsset.chain.chainFormat) else {
            return
        }

        let displayAddress = DisplayAddress(
            address: address,
            username: confirmModel.collatorIdentity?.displayName ?? ""
        )

        let viewModel = addressDisplayViewModelFactory.createViewModel(from: displayAddress)
        view?.didReceiveCollator(viewModel: viewModel)
    }

    private func provideNetworkFeeViewModel() {
        let assetInfo = chainAsset.assetDisplayInfo
        if let fee = extrinsicFee {
            let feeDecimal = Decimal.fromSubstrateAmount(
                fee.amount,
                precision: assetInfo.assetPrecision
            ) ?? 0.0

            let viewModel = balanceViewModelFactory.balanceFromPrice(feeDecimal, priceData: price)
                .value(for: selectedLocale)

            view?.didReceiveNetworkFee(viewModel: viewModel)
        } else {
            view?.didReceiveNetworkFee(viewModel: nil)
        }
    }

    func updateView() {
        provideWalletViewModel()
        provideAccountViewModel()
        provideNetworkFeeViewModel()
        provideCollatorViewModel()
        providePeriod()
        provideThreshold()
    }
}

extension ParaStkYieldBoostStartPresenter: ParaStkYieldBoostStartPresenterProtocol {
    func setup() {
        updateView()

        interactor.setup()

        refreshExecutionTime()
        refreshFee()
    }

    func submit() {
        let assetInfo = chainAsset.assetDisplayInfo

        DataValidationRunner(validators: [
            dataValidatingFactory.has(
                fee: extrinsicFee,
                locale: selectedLocale
            ) { [weak self] in
                self?.refreshFee()
            },
            dataValidatingFactory.hasExecutionFee(
                executionFee,
                locale: selectedLocale
            ) { [weak self] in
                self?.refreshExecutionTime()
            },
            dataValidatingFactory.hasExecutionTime(executionTime, locale: selectedLocale) { [weak self] in
                self?.refreshExecutionTime()
            },
            dataValidatingFactory.enoughBalanceForThreshold(
                confirmModel.accountMinimum,
                balance: balance?.transferable,
                extrinsicFee: extrinsicFee,
                assetInfo: assetInfo,
                locale: selectedLocale
            ),
            dataValidatingFactory.enoughBalanceForExecutionFee(
                executionFee,
                balance: balance?.transferable,
                extrinsicFee: extrinsicFee,
                assetInfo: assetInfo,
                locale: selectedLocale
            )
        ]).runValidation { [weak self] in
            self?.performSubmition()
        }
    }

    func showSenderActions() {
        guard let view = view, let address = selectedAccount.chainAccount.toAddress() else {
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

extension ParaStkYieldBoostStartPresenter: ParaStkYieldBoostStartInteractorOutputProtocol {
    func didReceiveYieldBoost(tasks: [ParaStkYieldBoostState.Task]?) {
        yieldBoostTasks = tasks
    }

    func didReceiveAsset(balance: AssetBalance?) {
        self.balance = balance
    }

    func didReceiveAsset(price: PriceData?) {
        self.price = price

        provideNetworkFeeViewModel()
    }

    func didReceiveCommonInteractor(error: ParaStkYieldBoostCommonInteractorError) {
        switch error {
        case .balanceSubscriptionFailed, .priceSubscriptionFailed, .yieldBoostTasksSubscriptionFailed:
            wireframe.presentFeeStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.retryCommonSubscriptions()
            }
        }
    }

    func didScheduleYieldBoost(for model: ExtrinsicSubmittedModel) {
        view?.didStopLoading()

        wireframe.presentExtrinsicSubmission(
            from: view,
            sender: model.sender,
            completionAction: .dismiss,
            locale: selectedLocale
        )
    }

    func didReceiveConfirmation(error: ParaStkYieldBoostStartError) {
        logger.error("Did receive confirmation error: \(error)")

        switch error {
        case let .yieldBoostScheduleFailed(error):
            view?.didStopLoading()

            wireframe.handleExtrinsicSigningErrorPresentationElseDefault(
                error,
                view: view,
                closeAction: .dismiss,
                locale: selectedLocale,
                completionClosure: nil
            )
        }
    }

    func didReceiveScheduleAutocompound(feeInfo: ExtrinsicFeeProtocol) {
        extrinsicFee = feeInfo

        provideNetworkFeeViewModel()
    }

    func didReceiveTaskExecution(fee: BigUInt) {
        executionFee = fee
    }

    func didReceiveTaskExecution(time: AutomationTime.UnixTime) {
        executionTime = time

        refreshFee()
    }

    func didReceiveScheduleInteractor(error: ParaStkYieldBoostScheduleInteractorError) {
        logger.error("Did receive schedule error: \(error)")

        switch error {
        case .scheduleFeeFetchFailed:
            wireframe.presentFeeStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.refreshFee()
            }
        case .taskExecutionFeeFetchFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.estimateTaskExecutionFee()
            }
        case .taskExecutionTimeFetchFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.refreshExecutionTime()
            }
        }
    }

    func didReceive(assetBalance: AssetBalance?) {
        balance = assetBalance
    }
}

extension ParaStkYieldBoostStartPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideNetworkFeeViewModel()
            provideThreshold()
        }
    }
}
