import Foundation
import BigInt
import SoraFoundation

final class ParaStkYieldBoostScheduleConfirmPresenter {
    weak var view: ParaStkYieldBoostScheduleConfirmViewProtocol?
    let wireframe: ParaStkYieldBoostScheduleConfirmWireframeProtocol
    let interactor: ParaStkYieldBoostScheduleConfirmInteractorInputProtocol

    let chainAsset: ChainAsset
    let selectedAccount: ChainAccountResponse
    let confirmModel: ParaStkYieldBoostConfirmModel
    let dataValidatingFactory: ParaStkYieldBoostValidatorFactoryProtocol
    let logger: LoggerProtocol

    private(set) var yieldBoostTasks: [ParaStkYieldBoostState.Task]?
    private(set) var executionFee: BigUInt?
    private(set) var extrinsicFee: BigUInt?
    private(set) var executionTime: AutomationTime.UnixTime?
    private(set) var balance: AssetBalance?
    private(set) var price: PriceData?

    init(
        interactor: ParaStkYieldBoostScheduleConfirmInteractorInputProtocol,
        wireframe: ParaStkYieldBoostScheduleConfirmWireframeProtocol,
        chainAsset: ChainAsset,
        selectedAccount: ChainAccountResponse,
        confirmModel: ParaStkYieldBoostConfirmModel,
        dataValidatingFactory: ParaStkYieldBoostValidatorFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.confirmModel = confirmModel
        self.dataValidatingFactory = dataValidatingFactory
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
    }

    func performSubmition() {
        if
            let executionTime = executionTime,
            let accountMinimum = confirmModel.accountMinimum.toSubstrateAmount(
                precision: chainAsset.assetDisplayInfo.assetPrecision
            ) {
            let cancellingTaskIds = yieldBoostTasks?.map(\.taskId)

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
}

extension ParaStkYieldBoostScheduleConfirmPresenter: ParaStkYieldBoostScheduleConfirmPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func submit() {
        let assetInfo = chainAsset.assetDisplayInfo
        let precision = assetInfo.assetPrecision

        DataValidationRunner(validators: [
            dataValidatingFactory.hasInPlank(
                fee: extrinsicFee,
                locale: selectedLocale,
                precision: precision
            ) { [weak self] in
                self?.refreshFee()
            },
            dataValidatingFactory.hasInPlank(
                fee: executionFee,
                locale: selectedLocale,
                precision: precision
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
        guard
            let view = view,
            let address = try? selectedAccount.accountId.toAddress(using: chainAsset.chain.chainFormat) else {
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

extension ParaStkYieldBoostScheduleConfirmPresenter: ParaStkYieldBoostScheduleConfirmInteractorOutputProtocol {
    func didReceiveYieldBoost(tasks: [ParaStkYieldBoostState.Task]?) {
        yieldBoostTasks = tasks
    }

    func didReceiveAsset(balance: AssetBalance?) {
        self.balance = balance
    }

    func didReceiveAsset(price: PriceData?) {
        self.price = price
    }

    func didReceiveCommonInteractor(error: ParaStkYieldBoostCommonInteractorError) {
        switch error {
        case .balanceSubscriptionFailed, .priceSubscriptionFailed, .yieldBoostTasksSubscriptionFailed:
            wireframe.presentFeeStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.retryCommonSubscriptions()
            }
        }
    }

    func didScheduleYieldBoost(for _: String) {}

    func didReceiveConfirmation(error: ParaStkYieldBoostScheduleConfirmError) {
        logger.error("Did receive confirmation error: \(error)")

        switch error {
        case let .yieldBoostScheduleFailed(error):
            if error.isWatchOnlySigning {
                wireframe.presentDismissingNoSigningView(from: view)
            } else {
                _ = wireframe.present(error: error, from: view, locale: selectedLocale)
            }
        }
    }

    func didReceiveScheduleAutocompound(feeInfo: RuntimeDispatchInfo) {
        extrinsicFee = BigUInt(feeInfo.fee)
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

extension ParaStkYieldBoostScheduleConfirmPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {}
    }
}
