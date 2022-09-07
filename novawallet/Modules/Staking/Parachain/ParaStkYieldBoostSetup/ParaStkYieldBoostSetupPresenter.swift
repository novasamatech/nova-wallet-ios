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

    private func activeCollatorDelegationInPlank() -> BigUInt? {
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

    init(
        interactor: ParaStkYieldBoostSetupInteractorInputProtocol,
        wireframe: ParaStkYieldBoostSetupWireframeProtocol,
        initState: ParaStkYieldBoostInitState,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        accountDetailsViewModelFactory: ParaStkAccountDetailsViewModelFactoryProtocol,
        chainAsset: ChainAsset,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.delegator = initState.delegator
        self.chainAsset = chainAsset
        self.scheduledRequests = initState.scheduledRequests
        self.delegationIdentities = initState.delegationIdentities
        self.balanceViewModelFactory = balanceViewModelFactory
        self.accountDetailsViewModelFactory = accountDetailsViewModelFactory
        self.yieldBoostTasks = initState.yieldBoostTasks
        self.localizationManager = localizationManager
    }

    private static func disabledCollatorsForYieldBoost(
        from scheduledRequests: [ParachainStaking.DelegatorScheduledRequest]
    ) -> Set<AccountId> {
        Set(scheduledRequests.filter({ $0.isRevoke }).map({ $0.collatorId }))
    }

    private static func findPreferredCollator(
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

    private func setupCollatorIfNeeded() {
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

    private func refreshYieldBoostParamsIfNeeded() {
        guard
            let selectedCollator = selectedCollator,
            let activeStake = activeCollatorDelegationInPlank() else {
            return
        }

        view?.didStartLoading()

        interactor.requestParams(for: activeStake, collator: selectedCollator)
    }

    private func provideCollatorViewModel() {
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

    private func createRewardViewModel(
        from percent: Decimal?,
        stake: Decimal?,
        formatter: LocalizableResource<NumberFormatter>
    ) -> ParaStkYieldBoostComparisonViewModel.Reward? {
        guard let percent = percent, let stake = stake else {
            return nil
        }

        let rewardAmount = percent * stake

        let amountViewModel = balanceViewModelFactory.balanceFromPrice(rewardAmount, priceData: price).value(for: selectedLocale)
        let percentString = formatter.value(for: selectedLocale).stringFromDecimal(percent) ?? ""

        return ParaStkYieldBoostComparisonViewModel.Reward(percent: percentString, amount: amountViewModel)
    }

    private func provideRewardsOptionComparisonViewModel() {
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

    private func provideRewardOptionSelectionViewModel() {
        view?.didReceiveYieldBoostSelected(isYieldBoostSelected)
    }

    private func provideYieldBoostPeriodViewModel() {
        view?.didReceiveYieldBoostPeriod(days: yieldBoostParams?.period)
    }

    private func provideAssetViewModel() {
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

    private func provideThresholdInputViewModel() {
        let inputAmount = thresholdInput?.absoluteValue(from: maxSpendingAmount())

        let viewModel = balanceViewModelFactory.createBalanceInputViewModel(
            inputAmount
        ).value(for: selectedLocale)

        view?.didReceiveAmount(inputViewModel: viewModel)
    }

    private func provideYieldBoostSpecificViewModels() {
        provideYieldBoostPeriodViewModel()
        provideAssetViewModel()
        provideThresholdInputViewModel()
    }

    private func provideViewModels() {
        provideCollatorViewModel()
        provideRewardsOptionComparisonViewModel()
        provideRewardOptionSelectionViewModel()

        if isYieldBoostSelected {
            provideYieldBoostSpecificViewModels()
        }
    }
}

extension ParaStkYieldBoostSetupPresenter: ParaStkYieldBoostSetupPresenterProtocol {
    func setup() {
        interactor.setup()

        setupCollatorIfNeeded()
        refreshYieldBoostParamsIfNeeded()

        provideViewModels()
    }
}

extension ParaStkYieldBoostSetupPresenter: ParaStkYieldBoostSetupInteractorOutputProtocol {
    func didReceiveAssetBalance(_ balance: AssetBalance?) {
        self.balance = balance
    }

    func didReceiveRewardCalculator(_ calculator: ParaStakingRewardCalculatorEngineProtocol) {
        self.rewardCalculator = calculator
    }

    func didReceivePrice(_ priceData: PriceData?) {
        self.price = priceData
    }

    func didReceiveDelegator(_ delegator: ParachainStaking.Delegator?) {
        self.delegator = delegator
    }

    func didReceiveDelegationIdentities(_ identities: [AccountId: AccountIdentity]?) {
        self.delegationIdentities = identities
    }

    func didReceiveScheduledRequests(_ scheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?) {
        self.scheduledRequests = scheduledRequests
    }

    func didReceiveYieldBoostTasks(_ tasks: [ParaStkYieldBoostState.Task]) {
        self.yieldBoostTasks = tasks
    }

    func didReceiveYieldBoostParams(_ params: ParaStkYieldBoostResponse, stake: BigUInt, collator: AccountId) {
        self.yieldBoostParams = params
    }

    func didReceiveError(_ error: ParaStkYieldBoostSetupInteractorError) {

    }
}

extension ParaStkYieldBoostSetupPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideViewModels()
        }
    }
}
