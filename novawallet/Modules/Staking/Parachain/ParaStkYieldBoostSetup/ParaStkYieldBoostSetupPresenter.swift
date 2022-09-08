import Foundation
import BigInt
import SoraFoundation

final class ParaStkYieldBoostSetupPresenter {
    weak var view: ParaStkYieldBoostSetupViewProtocol?
    let wireframe: ParaStkYieldBoostSetupWireframeProtocol
    let interactor: ParaStkYieldBoostSetupInteractorInputProtocol
    let chainAsset: ChainAsset
    let accountDetailsViewModelFactory: ParaStkAccountDetailsViewModelFactoryProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let logger: LoggerProtocol

    private(set) var thresholdInput: AmountInputResult?
    private(set) var delegator: ParachainStaking.Delegator?
    private(set) var delegationIdentities: [AccountId: AccountIdentity]?
    private(set) var scheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?
    private(set) var yieldBoostTasks: [ParaStkYieldBoostState.Task]?
    private(set) var balance: AssetBalance?
    private(set) var price: PriceData?
    private(set) var rewardCalculator: ParaStakingRewardCalculatorEngineProtocol?
    private(set) var yieldBoostParams: ParaStkYieldBoostResponse?
    private(set) var isYieldBoostSelected: Bool = false

    private lazy var aprFormatter = NumberFormatter.positivePercentAPR.localizableResource()
    private lazy var apyFormatter = NumberFormatter.positivePercentAPY.localizableResource()

    private(set) var selectedCollator: AccountId?

    init(
        interactor: ParaStkYieldBoostSetupInteractorInputProtocol,
        wireframe: ParaStkYieldBoostSetupWireframeProtocol,
        initState: ParaStkYieldBoostInitState,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        accountDetailsViewModelFactory: ParaStkAccountDetailsViewModelFactoryProtocol,
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
        self.accountDetailsViewModelFactory = accountDetailsViewModelFactory
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

        return balance
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
        guard let task = yieldBoostTasks?.first(where: { $0.collatorId == selectedCollator }) else {
            return nil
        }

        return UInt(bitPattern: TimeInterval(task.frequency).daysFromSeconds)
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

    func provideCollatorViewModel() {
        if
            let selectedCollator = selectedCollator,
            let address = try? selectedCollator.toAddress(using: chainAsset.chain.chainFormat) {
            let collatorDisplayAddress = DisplayAddress(
                address: address,
                username: delegationIdentities?[selectedCollator]?.name ?? ""
            )

            let collatorViewModel = accountDetailsViewModelFactory.createCollator(
                from: collatorDisplayAddress,
                delegator: delegator,
                locale: selectedLocale
            )

            view?.didReceiveCollator(viewModel: collatorViewModel)
        } else {
            view?.didReceiveCollator(viewModel: nil)
        }
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

    func provideRewardsOptionComparisonViewModel() {
        guard let activeStake = activeCollatorDelegationInPlank(), let selectedCollator = selectedCollator else {
            view?.didReceiveRewardComparison(viewModel: .empty)
            return
        }

        let activeStakeDecimal = Decimal.fromSubstrateAmount(
            activeStake,
            precision: chainAsset.assetDisplayInfo.assetPrecision
        )

        let apr: ParaStkYieldBoostComparisonViewModel.Reward?

        if
            let rewardCalculator = rewardCalculator,
            let calculatedApr = try? rewardCalculator.calculateEarnings(
                amount: 1.0,
                collatorAccountId: selectedCollator,
                period: .year
            ) {
            apr = createRewardViewModel(from: calculatedApr, stake: activeStakeDecimal, formatter: aprFormatter)
        } else {
            apr = nil
        }

        let apy = createRewardViewModel(from: yieldBoostParams?.apy, stake: activeStakeDecimal, formatter: apyFormatter)

        let viewModel = ParaStkYieldBoostComparisonViewModel(apr: apr, apy: apy)
        view?.didReceiveRewardComparison(viewModel: viewModel)
    }

    func provideRewardOptionSelectionViewModel() {
        view?.didReceiveYieldBoostSelected(isYieldBoostSelected)
    }

    func provideYieldBoostPeriodViewModel() {
        guard let newPeriod = yieldBoostParams?.period else {
            view?.didReceiveYieldBoostPeriod(viewModel: nil)
            return
        }

        let viewModel = ParaStkYieldBoostPeriodViewModel(
            old: selectedRemoteBoostPeriod(),
            new: newPeriod
        )

        view?.didReceiveYieldBoostPeriod(viewModel: viewModel)
    }

    func provideAssetViewModel() {
        let balanceDecimal = balance.flatMap { value in
            Decimal.fromSubstrateAmount(
                value.transferable,
                precision: chainAsset.assetDisplayInfo.assetPrecision
            )
        } ?? 0

        let inputAmount = thresholdInput?.absoluteValue(from: maxSpendingAmount()) ?? 0
        let viewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            inputAmount,
            balance: balanceDecimal,
            priceData: price
        ).value(for: selectedLocale)

        view?.didReceiveAssetBalance(viewModel: viewModel)
    }

    func provideThresholdInputViewModel() {
        let inputAmount = thresholdInput?.absoluteValue(from: maxSpendingAmount()) ??
            selectedRemoteBoostThreshold()

        let viewModel = balanceViewModelFactory.createBalanceInputViewModel(
            inputAmount
        ).value(for: selectedLocale)

        view?.didReceiveAmount(inputViewModel: viewModel)
    }

    func updateHasChanges() {
        view?.didReceiveHasChanges(viewModel: checkChanges())
    }

    func provideYieldBoostSpecificViewModels() {
        provideYieldBoostPeriodViewModel()
        provideAssetViewModel()
        provideThresholdInputViewModel()
    }

    func provideViewModels() {
        provideCollatorViewModel()
        provideRewardsOptionComparisonViewModel()
        provideRewardOptionSelectionViewModel()

        if isYieldBoostSelected {
            provideYieldBoostSpecificViewModels()
        }

        updateHasChanges()
    }
}

extension ParaStkYieldBoostSetupPresenter: ParaStkYieldBoostSetupPresenterProtocol {
    func setup() {
        interactor.setup()

        setupCollatorIfNeeded()
        refreshYieldBoostParamsIfNeeded()

        provideViewModels()
    }

    func switchRewardsOption(to isYieldBoosted: Bool) {
        guard isYieldBoostSelected != isYieldBoosted else {
            return
        }

        isYieldBoostSelected = isYieldBoosted

        provideRewardOptionSelectionViewModel()

        if isYieldBoostSelected {
            provideYieldBoostSpecificViewModels()
        }

        updateHasChanges()
    }

    func updateThresholdAmount(_ newValue: Decimal?) {
        thresholdInput = newValue.map { .absolute($0) }

        provideAssetViewModel()
        updateHasChanges()
    }

    func selectThresholdAmountPercentage(_ percentage: Float) {
        thresholdInput = .rate(Decimal(Double(percentage)))

        provideThresholdInputViewModel()
        provideAssetViewModel()
        updateHasChanges()
    }

    func selectCollator() {
        guard let delegator = delegator else {
            return
        }

        let delegations = delegator.delegations.sorted { $0.amount > $1.amount }
        let disabledCollators = Self.disabledCollatorsForYieldBoost(from: scheduledRequests ?? [])

        guard delegations.count > disabledCollators.count else {
            return
        }

        let accountDetailsViewModels = accountDetailsViewModelFactory.createViewModels(
            from: delegations,
            identities: delegationIdentities,
            disabled: disabledCollators
        )

        let selectedIndex = delegations.firstIndex { $0.owner == selectedCollator } ?? NSNotFound

        wireframe.showDelegationSelection(
            from: view,
            viewModels: accountDetailsViewModels,
            selectedIndex: selectedIndex,
            delegate: self,
            context: delegations as NSArray
        )
    }

    func proceed() {
        // TODO: Implement transition to confirmation
    }
}

extension ParaStkYieldBoostSetupPresenter: ParaStkYieldBoostSetupInteractorOutputProtocol {
    func didReceiveAssetBalance(_ balance: AssetBalance?) {
        self.balance = balance

        if isYieldBoostSelected {
            provideAssetViewModel()
            provideThresholdInputViewModel()
            updateHasChanges()
        }
    }

    func didReceiveRewardCalculator(_ calculator: ParaStakingRewardCalculatorEngineProtocol) {
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
    }

    func didReceiveYieldBoostParams(_ params: ParaStkYieldBoostResponse, stake _: BigUInt, collator _: AccountId) {
        yieldBoostParams = params

        view?.didStopLoading()

        provideRewardsOptionComparisonViewModel()

        if isYieldBoostSelected {
            provideYieldBoostPeriodViewModel()
        }

        updateHasChanges()
    }

    func didReceiveError(_ error: ParaStkYieldBoostSetupInteractorError) {
        logger.error("Did receive error \(error)")

        switch error {
        case .rewardCalculatorFetchFailed:
            break
        case .identitiesFetchFailed:
            break
        case .balanceSubscriptionFailed:
            break
        case .priceSubscriptionFailed:
            break
        case .delegatorSubscriptionFailed:
            break
        case .scheduledRequestsSubscriptionFailed:
            break
        case .yieldBoostTaskSubscriptionFailed:
            break
        case let .yieldBoostParamsFailed(_, stake, collator):
            view?.didStopLoading()
        }
    }
}

extension ParaStkYieldBoostSetupPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        guard let delegations = context as? [ParachainStaking.Bond] else {
            return
        }

        selectedCollator = delegations[index].owner

        yieldBoostParams = nil
        isYieldBoostSelected = yieldBoostTasks?.contains { $0.collatorId == selectedCollator } ?? false
        thresholdInput = nil

        refreshYieldBoostParamsIfNeeded()
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
