import Foundation
import BigInt
import Foundation_iOS

final class ParaStkYieldBoostSetupPresenter {
    weak var view: ParaStkYieldBoostSetupViewProtocol?
    let wireframe: ParaStkYieldBoostSetupWireframeProtocol
    let interactor: ParaStkYieldBoostSetupInteractorInputProtocol
    let chainAsset: ChainAsset
    let collatorSelectionViewModelFactory: YieldBoostCollatorSelectionFactoryProtocol
    let accountDetailsViewModelFactory: CollatorStakingAccountViewModelFactoryProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let dataValidatingFactory: ParaStkYieldBoostValidatorFactoryProtocol
    let logger: LoggerProtocol

    private(set) var thresholdInput: AmountInputResult?
    private(set) var delegator: ParachainStaking.Delegator?
    private(set) var delegationIdentities: [AccountId: AccountIdentity]?
    private(set) var scheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?
    private(set) var yieldBoostTasks: [ParaStkYieldBoostState.Task]?
    private(set) var balance: AssetBalance?
    private(set) var price: PriceData?
    private(set) var rewardCalculator: CollatorStakingRewardCalculatorEngineProtocol?
    private(set) var yieldBoostParams: ParaStkYieldBoostResponse?
    private(set) var isYieldBoostSelected: Bool = false
    private(set) var extrinsicFee: ExtrinsicFeeProtocol?
    private(set) var taskExecutionFee: BigUInt?
    private(set) var taskExecutionTime: AutomationTime.UnixTime?

    private(set) lazy var aprFormatter = NumberFormatter.positivePercentAPR.localizableResource()
    private(set) lazy var apyFormatter = NumberFormatter.positivePercentAPY.localizableResource()

    private(set) var selectedCollator: AccountId?

    init(
        interactor: ParaStkYieldBoostSetupInteractorInputProtocol,
        wireframe: ParaStkYieldBoostSetupWireframeProtocol,
        initState: ParaStkYieldBoostInitState,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        collatorSelectionViewModelFactory: YieldBoostCollatorSelectionFactoryProtocol,
        accountDetailsViewModelFactory: CollatorStakingAccountViewModelFactoryProtocol,
        dataValidatingFactory: ParaStkYieldBoostValidatorFactoryProtocol,
        chainAsset: ChainAsset,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        delegator = initState.delegator
        self.chainAsset = chainAsset
        scheduledRequests = initState.scheduledRequests
        delegationIdentities = initState.delegationIdentities
        self.balanceViewModelFactory = balanceViewModelFactory
        self.collatorSelectionViewModelFactory = collatorSelectionViewModelFactory
        self.accountDetailsViewModelFactory = accountDetailsViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        yieldBoostTasks = initState.yieldBoostTasks
        self.logger = logger
        self.localizationManager = localizationManager
    }

    func activeCollatorDelegationInPlank() -> BigUInt? {
        guard let stake = delegator?.delegations.first(where: { $0.owner == selectedCollator })?.amount else {
            return nil
        }

        if let request = scheduledRequests?.first(where: { $0.collatorId == selectedCollator }) {
            let unstakingAmount = request.unstakingAmount
            return stake >= unstakingAmount ? stake - unstakingAmount : 0
        } else {
            return stake
        }
    }

    func maxSpendingAmount() -> Decimal {
        let balanceValue = balance?.transferable ?? 0

        let precision = chainAsset.assetDisplayInfo.assetPrecision

        guard let balance = Decimal.fromSubstrateAmount(balanceValue, precision: precision) else {
            return 0
        }

        let extrinsicFeeDecimal = Decimal.fromSubstrateAmount(
            extrinsicFee?.amountForCurrentAccount ?? 0,
            precision: precision
        ) ?? 0

        return max(balance - extrinsicFeeDecimal, 0)
    }

    func isRemoteYieldBoosted() -> Bool {
        yieldBoostTasks?.contains { $0.collatorId == selectedCollator } ?? false
    }

    func selectedRemoteBoostThreshold() -> Decimal? {
        guard let task = yieldBoostTasks?.first(where: { $0.collatorId == selectedCollator }) else {
            return nil
        }

        let precision = chainAsset.assetDisplayInfo.assetPrecision

        return Decimal.fromSubstrateAmount(task.accountMinimum, precision: precision)
    }

    func selectedRemoteBoostPeriod() -> UInt? {
        guard
            let task = yieldBoostTasks?.first(where: { $0.collatorId == selectedCollator }),
            let frequency = task.frequency else {
            return nil
        }

        return UInt(bitPattern: TimeInterval(frequency).daysFromSeconds)
    }

    func checkChanges() -> Bool {
        if isYieldBoostSelected != isRemoteYieldBoosted() {
            return true
        }

        if !isYieldBoostSelected {
            return false
        }

        if selectedRemoteBoostPeriod() != yieldBoostParams?.period {
            return true
        }

        if
            let inputAmount = thresholdInput?.absoluteValue(from: maxSpendingAmount()),
            selectedRemoteBoostThreshold() != inputAmount {
            return true
        }

        return false
    }

    static func disabledCollatorsForYieldBoost(
        from scheduledRequests: [ParachainStaking.DelegatorScheduledRequest]
    ) -> Set<AccountId> {
        Set(scheduledRequests.filter { $0.isRevoke }.map(\.collatorId))
    }

    static func findPreferredCollator(
        from delegatorState: ParachainStaking.Delegator,
        scheduledRequests: [ParachainStaking.DelegatorScheduledRequest],
        yieldBoostTasks: [ParaStkYieldBoostState.Task]
    ) -> AccountId? {
        if let yieldBoostedCollator = yieldBoostTasks.first?.collatorId {
            return yieldBoostedCollator
        }

        let disableCollators = disabledCollatorsForYieldBoost(from: scheduledRequests)

        return delegatorState.delegations
            .filter { delegation in
                !disableCollators.contains(delegation.owner)
            }
            .max { $0.amount < $1.amount }?
            .owner
    }

    func updateYieldBoostSelected(_ newValue: Bool) {
        isYieldBoostSelected = newValue
    }

    func updateThresholdInput(_ newValue: AmountInputResult?) {
        thresholdInput = newValue
    }

    func updateExtrinsicFee(_ newValue: ExtrinsicFeeProtocol?) {
        extrinsicFee = newValue

        if case .rate = thresholdInput {
            provideThresholdInputViewModel()
        }
    }

    func updateTaskExecutionFee(_ newValue: BigUInt?) {
        taskExecutionFee = newValue

        if case .rate = thresholdInput {
            provideThresholdInputViewModel()
        }
    }

    func updateTaskExecutionTime(_ newValue: AutomationTime.UnixTime?) {
        taskExecutionTime = newValue
    }

    func refreshExtrinsicFee() {
        extrinsicFee = nil

        if isYieldBoostSelected {
            interactor.estimateTaskExecutionFee()

            let accountMinimumDecimal = thresholdInput?.absoluteValue(from: maxSpendingAmount()) ??
                selectedRemoteBoostThreshold()

            let precision = chainAsset.assetDisplayInfo.assetPrecision

            if
                let selectedCollator = selectedCollator,
                let executionTime = taskExecutionTime,
                let period = yieldBoostParams?.period {
                let accountMinimum = accountMinimumDecimal?.toSubstrateAmount(precision: precision) ?? 0
                let existingTaskIds = yieldBoostTasks?.map(\.taskId)

                interactor.estimateScheduleAutocompoundFee(
                    for: selectedCollator,
                    initTime: executionTime,
                    frequency: AutomationTime.Seconds(TimeInterval(period).secondsFromDays),
                    accountMinimum: accountMinimum,
                    cancellingTaskIds: Set(existingTaskIds ?? [])
                )
            }
        } else {
            if let taskId = yieldBoostTasks?.first(where: { $0.collatorId == selectedCollator })?.taskId {
                interactor.estimateCancelAutocompoundFee(for: taskId)
            } else {
                // yield boost is not enabled so try to estimate using dummy parameters
                let period = yieldBoostParams.map { AutomationTime.Seconds(TimeInterval($0.period).secondsFromDays) }

                interactor.estimateScheduleAutocompoundFee(
                    for: selectedCollator ?? AccountId.zeroAccountId(of: chainAsset.chain.accountIdSize),
                    initTime: taskExecutionTime ?? 0,
                    frequency: period ?? AutomationTime.Seconds(TimeInterval.secondsInHour),
                    accountMinimum: 0,
                    cancellingTaskIds: Set()
                )
            }
        }

        provideNetworkFee()
    }

    func refreshFeeIfNeeded() {
        taskExecutionFee = nil

        if isYieldBoostSelected {
            interactor.estimateTaskExecutionFee()
        }

        refreshExtrinsicFee()
    }

    func refreshTaskExecutionTime() {
        taskExecutionTime = nil

        if let period = yieldBoostParams?.period {
            interactor.fetchTaskExecutionTime(for: period)
        }
    }

    func setupCollatorIfNeeded() {
        guard selectedCollator == nil else {
            return
        }

        if
            let delegator = delegator,
            let scheduledRequests = scheduledRequests,
            let yieldBoostTasks = yieldBoostTasks {
            selectedCollator = Self.findPreferredCollator(
                from: delegator,
                scheduledRequests: scheduledRequests,
                yieldBoostTasks: yieldBoostTasks
            )

            isYieldBoostSelected = yieldBoostTasks.contains { $0.collatorId == selectedCollator }
        }
    }

    func refreshYieldBoostParamsIfNeeded() {
        guard
            let selectedCollator = selectedCollator,
            let activeStake = activeCollatorDelegationInPlank() else {
            return
        }

        view?.didStartLoading()

        interactor.requestParams(for: activeStake, collator: selectedCollator)
    }

    func createRewardViewModel(
        from percent: Decimal?,
        stake: Decimal?,
        formatter: LocalizableResource<NumberFormatter>
    ) -> ParaStkYieldBoostComparisonViewModel.Reward? {
        guard let percent = percent, let stake = stake else {
            return nil
        }

        let rewardAmount = percent * stake

        let amountViewModel = balanceViewModelFactory.balanceFromPrice(
            rewardAmount,
            priceData: price ?? PriceData.zero()
        ).value(for: selectedLocale)

        let percentString = formatter.value(for: selectedLocale).stringFromDecimal(percent) ?? ""

        return ParaStkYieldBoostComparisonViewModel.Reward(percent: percentString, balance: amountViewModel)
    }
}

extension ParaStkYieldBoostSetupPresenter: ParaStkYieldBoostSetupInteractorOutputProtocol {
    func didReceiveAssetBalance(_ balance: AssetBalance?) {
        self.balance = balance

        if isYieldBoostSelected {
            provideAssetViewModel()
            updateHasChanges()
            refreshFeeIfNeeded()

            if case .rate = thresholdInput {
                provideThresholdInputViewModel()
            }
        }
    }

    func didReceiveRewardCalculator(_ calculator: CollatorStakingRewardCalculatorEngineProtocol) {
        rewardCalculator = calculator

        provideRewardsOptionComparisonViewModel()
    }

    func didReceivePrice(_ priceData: PriceData?) {
        price = priceData

        provideRewardsOptionComparisonViewModel()

        if isYieldBoostSelected {
            provideAssetViewModel()
        }
    }

    func didReceiveDelegator(_ delegator: ParachainStaking.Delegator?) {
        self.delegator = delegator

        setupCollatorIfNeeded()

        provideCollatorViewModel()

        provideRewardsOptionComparisonViewModel()
    }

    func didReceiveDelegationIdentities(_ identities: [AccountId: AccountIdentity]?) {
        delegationIdentities = identities

        provideCollatorViewModel()
    }

    func didReceiveScheduledRequests(_ scheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?) {
        self.scheduledRequests = scheduledRequests

        setupCollatorIfNeeded()

        provideCollatorViewModel()
        provideRewardsOptionComparisonViewModel()
    }

    func didReceiveYieldBoostTasks(_ tasks: [ParaStkYieldBoostState.Task]) {
        yieldBoostTasks = tasks

        setupCollatorIfNeeded()

        provideRewardsOptionComparisonViewModel()

        if isYieldBoostSelected, thresholdInput == nil {
            provideThresholdInputViewModel()
        }

        if isYieldBoostSelected {
            provideYieldBoostPeriodViewModel()
        }

        updateHasChanges()

        refreshFeeIfNeeded()
    }

    func didReceiveYieldBoostParams(_ params: ParaStkYieldBoostResponse, stake _: BigUInt, collator _: AccountId) {
        yieldBoostParams = params

        view?.didStopLoading()

        provideRewardsOptionComparisonViewModel()

        updateHasChanges()

        if isYieldBoostSelected {
            provideYieldBoostPeriodViewModel()

            refreshFeeIfNeeded()
            refreshTaskExecutionTime()
        }
    }

    func didReceiveError(_ error: ParaStkYieldBoostSetupInteractorError) {
        logger.error("Did receive error \(error)")

        switch error {
        case .rewardCalculatorFetchFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.fetchRewardCalculator()
            }
        case .identitiesFetchFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                if let collators = self?.delegator?.collators() {
                    self?.interactor.fetchIdentities(for: collators)
                }
            }
        case .balanceSubscriptionFailed, .priceSubscriptionFailed, .delegatorSubscriptionFailed,
             .scheduledRequestsSubscriptionFailed, .yieldBoostTaskSubscriptionFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.retrySubscriptions()
            }
        case .yieldBoostParamsFailed:
            view?.didStopLoading()

            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.refreshYieldBoostParamsIfNeeded()
            }
        }
    }
}

extension ParaStkYieldBoostSetupPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        guard let delegations = context as? [YieldBoostCollatorSelection] else {
            return
        }

        selectedCollator = delegations[index].collatorId

        yieldBoostParams = nil
        isYieldBoostSelected = yieldBoostTasks?.contains { $0.collatorId == selectedCollator } ?? false
        thresholdInput = nil

        refreshYieldBoostParamsIfNeeded()
        refreshFeeIfNeeded()

        provideViewModels()
    }
}

extension ParaStkYieldBoostSetupPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideViewModels()
        }
    }
}
