import Foundation
import Foundation_iOS
import BigInt

final class ParaStkStakeSetupPresenter {
    weak var view: CollatorStakingSetupViewProtocol?
    let wireframe: ParaStkStakeSetupWireframeProtocol
    let interactor: ParaStkStakeSetupInteractorInputProtocol

    let chainAsset: ChainAsset
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let dataValidatingFactory: ParaStkValidatorFactoryProtocol
    let accountDetailsViewModelFactory: CollatorStakingAccountViewModelFactoryProtocol

    private(set) var inputResult: AmountInputResult?
    private(set) var fee: ExtrinsicFeeProtocol?
    private(set) var balance: AssetBalance?
    private(set) var minTechStake: BigUInt?
    private(set) var minDelegationAmount: BigUInt?
    private(set) var maxDelegations: UInt32?
    private(set) var price: PriceData?
    private(set) var rewardCalculator: CollatorStakingRewardCalculatorEngineProtocol?

    private(set) var collatorDisplayAddress: DisplayAddress?
    private(set) var collatorMetadata: ParachainStaking.CandidateMetadata?
    private(set) var delegator: ParachainStaking.Delegator?
    private(set) var delegationIdentities: [AccountId: AccountIdentity]?
    private(set) var scheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?

    private lazy var aprFormatter = NumberFormatter.positivePercentAPR.localizableResource()

    let logger: LoggerProtocol

    init(
        interactor: ParaStkStakeSetupInteractorInputProtocol,
        wireframe: ParaStkStakeSetupWireframeProtocol,
        dataValidatingFactory: ParaStkValidatorFactoryProtocol,
        chainAsset: ChainAsset,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        accountDetailsViewModelFactory: CollatorStakingAccountViewModelFactoryProtocol,
        initialDelegator: ParachainStaking.Delegator?,
        initialScheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?,
        delegationIdentities: [AccountId: AccountIdentity]?,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.dataValidatingFactory = dataValidatingFactory
        self.chainAsset = chainAsset
        self.balanceViewModelFactory = balanceViewModelFactory
        self.accountDetailsViewModelFactory = accountDetailsViewModelFactory
        delegator = initialDelegator
        scheduledRequests = initialScheduledRequests
        self.delegationIdentities = delegationIdentities
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func createDisabledCollators() -> Set<AccountId> {
        let disabled = scheduledRequests?
            .filter { $0.isRevoke }
            .map(\.collatorId)

        return Set(disabled ?? [])
    }

    private func existingStakeInPlank() -> BigUInt? {
        if let collatorId = try? collatorDisplayAddress?.address.toAccountId() {
            return delegator?.delegations.first(where: { $0.owner == collatorId })?.amount
        } else {
            return nil
        }
    }

    private func allowedAmountToStake() -> BigUInt? {
        let totalStake = delegator?.total ?? 0
        let freeBalance = balance?.freeInPlank ?? 0

        return freeBalance >= totalStake ? freeBalance - totalStake : 0
    }

    func balanceMinusFee() -> Decimal {
        let balanceValue = allowedAmountToStake() ?? 0
        let feeValue = fee?.amountForCurrentAccount ?? 0

        let precision = chainAsset.assetDisplayInfo.assetPrecision

        guard
            let balance = Decimal.fromSubstrateAmount(balanceValue, precision: precision),
            let fee = Decimal.fromSubstrateAmount(feeValue, precision: precision) else {
            return 0
        }

        return balance - fee
    }

    private func provideAmountInputViewModel() {
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee())

        let viewModel = balanceViewModelFactory.createBalanceInputViewModel(
            inputAmount
        ).value(for: selectedLocale)

        view?.didReceiveAmount(inputViewModel: viewModel)
    }

    private func provideAssetViewModel() {
        let balanceDecimal = allowedAmountToStake().flatMap { value in
            Decimal.fromSubstrateAmount(
                value,
                precision: chainAsset.assetDisplayInfo.assetPrecision
            )
        }

        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee()) ?? 0
        let viewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            inputAmount,
            balance: balanceDecimal ?? 0.0,
            priceData: price
        ).value(for: selectedLocale)

        view?.didReceiveAssetBalance(viewModel: viewModel)
    }

    private func provideMinStakeViewModel() {
        let minStake: BigUInt?
        if
            let minTechStake = minTechStake,
            let minRewardableStake = collatorMetadata?.minRewardableStake(for: minTechStake) {
            minStake = minRewardableStake
        } else {
            minStake = minTechStake
        }

        let viewModel: BalanceViewModelProtocol? = minStake.flatMap { amount in
            guard let decimaAmount = Decimal.fromSubstrateAmount(
                amount,
                precision: chainAsset.assetDisplayInfo.assetPrecision
            ) else {
                return nil
            }

            return balanceViewModelFactory.balanceFromPrice(
                decimaAmount,
                priceData: price
            ).value(for: selectedLocale)
        }

        view?.didReceiveMinStake(viewModel: viewModel)
    }

    private func provideFeeViewModel() {
        let optFeeDecimal = fee.flatMap { value in
            Decimal.fromSubstrateAmount(
                value.amount,
                precision: chainAsset.assetDisplayInfo.assetPrecision
            )
        }

        if let feeDecimal = optFeeDecimal {
            let viewModel = balanceViewModelFactory.balanceFromPrice(
                feeDecimal,
                priceData: price
            ).value(for: selectedLocale)

            view?.didReceiveFee(viewModel: viewModel)
        } else {
            view?.didReceiveFee(viewModel: nil)
        }
    }

    private func provideRewardsViewModel() {
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee()) ?? 0

        let amountReturn: Decimal
        let exitingStake: Decimal

        if
            let rewardCalculator = rewardCalculator,
            let collatorId = try? collatorDisplayAddress?.address.toAccountId() {
            let calculatedReturn = try? rewardCalculator.calculateEarnings(
                amount: 1.0,
                collatorAccountId: collatorId,
                period: .year
            )

            amountReturn = calculatedReturn ?? 0

            let assetPrecision = chainAsset.assetDisplayInfo.assetPrecision
            let stakeInPlank = existingStakeInPlank() ?? 0
            exitingStake = Decimal.fromSubstrateAmount(stakeInPlank, precision: assetPrecision) ?? 0
        } else {
            let calculatedReturn = rewardCalculator?.calculateMaxReturn(for: .year)
            amountReturn = calculatedReturn ?? 0
            exitingStake = 0
        }

        let rewardAmount = (inputAmount + exitingStake) * amountReturn

        let balanceViewModel = balanceViewModelFactory.balanceFromPrice(
            rewardAmount,
            priceData: price ?? PriceData.zero()
        ).value(for: selectedLocale)

        let aprString = aprFormatter.value(for: selectedLocale).stringFromDecimal(amountReturn)

        let viewModel = StakingRewardInfoViewModel(
            amountViewModel: balanceViewModel,
            returnPercentage: aprString ?? ""
        )

        view?.didReceiveReward(viewModel: viewModel)
    }

    private func provideCollatorViewModel() {
        if let collatorDisplayAddress = collatorDisplayAddress {
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

    func refreshFee() {
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee()) ?? 0
        let precicion = chainAsset.assetDisplayInfo.assetPrecision

        guard let amount = inputAmount.toSubstrateAmount(precision: precicion) else {
            return
        }

        fee = nil
        provideFeeViewModel()

        let collatorsDelegationsCount = collatorMetadata?.delegationCount ?? 0
        let collator = try? collatorDisplayAddress?.address.toAccountId()

        let delegationsCount = delegator?.delegations.count ?? 0

        let callWrapper = DelegationCallWrapper(
            amount: amount,
            collator: collator ?? AccountId.zeroAccountId(of: chainAsset.chain.accountIdSize),
            collatorDelegationsCount: collatorsDelegationsCount,
            delegationsCount: UInt32(delegationsCount),
            existingBond: existingStakeInPlank()
        )

        interactor.estimateFee(with: callWrapper)
    }

    private func setupInitialCollator() {
        let disabled = createDisabledCollators()

        let optMaxCollator = delegator?.delegations
            .filter { !disabled.contains($0.owner) }
            .max { $0.amount < $1.amount }?
            .owner

        if
            let maxCollator = optMaxCollator,
            let address = try? maxCollator.toAddress(using: chainAsset.chain.chainFormat) {
            let name = delegationIdentities?[maxCollator]?.displayName
            collatorDisplayAddress = DisplayAddress(address: address, username: name ?? "")
        }
    }

    func changeCollator(with newAddress: DisplayAddress?) {
        guard
            let collatorId = try? newAddress?.address.toAccountId(using: chainAsset.chain.chainFormat),
            newAddress?.address != collatorDisplayAddress?.address else {
            return
        }

        collatorDisplayAddress = newAddress

        collatorMetadata = nil

        provideCollatorViewModel()
        provideMinStakeViewModel()
        provideRewardsViewModel()

        interactor.applyCollator(with: collatorId)
    }

    func changeCollator(with collatorId: AccountId, name: String?) {
        guard let newAddress = try? collatorId.toAddress(using: chainAsset.chain.chainFormat) else {
            return
        }

        changeCollator(with: DisplayAddress(address: newAddress, username: name ?? ""))
    }
}

extension ParaStkStakeSetupPresenter: CollatorStakingSetupPresenterProtocol {
    func setup() {
        setupInitialCollator()

        provideAmountInputViewModel()

        provideCollatorViewModel()
        provideAssetViewModel()
        provideMinStakeViewModel()
        provideFeeViewModel()

        interactor.setup()

        if let collatorId = try? collatorDisplayAddress?.address.toAccountId() {
            interactor.applyCollator(with: collatorId)
        }

        refreshFee()
    }

    func selectCollator() {
        if let delegator = delegator, !delegator.delegations.isEmpty {
            let delegations = delegator.delegations.sorted { $0.amount > $1.amount }
            let disabledCollators = createDisabledCollators()

            guard delegations.count > disabledCollators.count else {
                // all collators are disable - start staking
                wireframe.showCollatorSelection(from: view, delegate: self)
                return
            }

            let accountDetailsViewModels = accountDetailsViewModelFactory.createViewModelsFromBonds(
                delegations,
                identities: delegationIdentities,
                disabled: createDisabledCollators()
            )

            let collatorId = try? collatorDisplayAddress?.address.toAccountId()

            let selectedIndex = delegations.firstIndex { $0.owner == collatorId } ?? NSNotFound

            wireframe.showDelegationSelection(
                from: view,
                viewModels: accountDetailsViewModels,
                selectedIndex: selectedIndex,
                delegate: self,
                context: delegations as NSArray
            )

        } else {
            wireframe.showCollatorSelection(from: view, delegate: self)
        }
    }

    func updateAmount(_ newValue: Decimal?) {
        inputResult = newValue.map { .absolute($0) }

        refreshFee()
        provideAssetViewModel()
        provideRewardsViewModel()
    }

    func selectAmountPercentage(_ percentage: Float) {
        inputResult = .rate(Decimal(Double(percentage)))

        provideAmountInputViewModel()

        refreshFee()
        provideAssetViewModel()
        provideRewardsViewModel()
    }

    func proceed() {
        if let stakingAmount = existingStakeInPlank() {
            stakeMore(above: stakingAmount, allowedAmountToStake: allowedAmountToStake())
        } else {
            startStaking(for: allowedAmountToStake())
        }
    }
}

extension ParaStkStakeSetupPresenter: ParaStkStakeSetupInteractorOutputProtocol {
    func didReceiveAssetBalance(_ balance: AssetBalance?) {
        self.balance = balance

        provideAssetViewModel()
    }

    func didReceiveRewardCalculator(_ calculator: CollatorStakingRewardCalculatorEngineProtocol) {
        rewardCalculator = calculator

        provideRewardsViewModel()
    }

    func didReceivePrice(_ priceData: PriceData?) {
        price = priceData

        provideAssetViewModel()
        provideMinStakeViewModel()
        provideFeeViewModel()
        provideRewardsViewModel()
    }

    func didReceiveFee(_ result: Result<ExtrinsicFeeProtocol, Error>) {
        switch result {
        case let .success(feeInfo):
            fee = feeInfo

            provideFeeViewModel()
        case let .failure(error):
            logger.error("Did receive error: \(error)")

            wireframe.presentFeeStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.refreshFee()
            }
        }
    }

    func didReceiveMinTechStake(_ minStake: BigUInt) {
        minTechStake = minStake

        provideMinStakeViewModel()
    }

    func didReceiveCollator(metadata: ParachainStaking.CandidateMetadata?) {
        collatorMetadata = metadata

        provideMinStakeViewModel()
        provideRewardsViewModel()
        refreshFee()
    }

    func didReceiveDelegator(_ delegator: ParachainStaking.Delegator?) {
        self.delegator = delegator

        provideCollatorViewModel()
    }

    func didReceiveDelegationIdentities(_ identities: [AccountId: AccountIdentity]?) {
        delegationIdentities = identities

        if
            let collatorAddress = collatorDisplayAddress?.address,
            let collatorId = try? collatorAddress.toAccountId() {
            let displayName = identities?[collatorId]?.displayName ?? collatorDisplayAddress?.username

            collatorDisplayAddress = DisplayAddress(address: collatorAddress, username: displayName ?? "")
        }

        provideCollatorViewModel()
    }

    func didReceiveScheduledRequests(_ scheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?) {
        self.scheduledRequests = scheduledRequests
    }

    func didReceiveMinDelegationAmount(_ amount: BigUInt) {
        minDelegationAmount = amount
    }

    func didReceiveMaxDelegations(_ maxDelegations: UInt32) {
        self.maxDelegations = maxDelegations
    }

    func didReceivePreferredCollator(_ collator: DisplayAddress?) {
        if collator != nil, collatorDisplayAddress == nil {
            changeCollator(with: collator)
        }
    }

    func didReceiveError(_ error: Error) {
        _ = wireframe.present(error: error, from: view, locale: selectedLocale)

        logger.error("Did receive error: \(error)")
    }
}

extension ParaStkStakeSetupPresenter: CollatorStakingSelectDelegate {
    func didSelect(collator: CollatorStakingSelectionInfoProtocol) {
        changeCollator(with: collator.accountId, name: collator.identity?.displayName)
    }
}

extension ParaStkStakeSetupPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        guard let delegations = context as? [ParachainStaking.Bond] else {
            return
        }

        let collatorId = delegations[index].owner

        DataValidationRunner(validators: [
            dataValidatingFactory.notRevokingWhileStakingMore(
                collator: collatorId,
                scheduledRequests: scheduledRequests,
                locale: selectedLocale
            )
        ]).runValidation { [weak self] in
            let displayName = self?.delegationIdentities?[collatorId]?.displayName

            self?.changeCollator(with: collatorId, name: displayName)
        }
    }

    func modalPickerDidSelectAction(context _: AnyObject?) {
        DataValidationRunner(validators: [
            dataValidatingFactory.notExceedsMaxCollatorsForDelegator(
                delegator,
                selectedCollator: nil,
                maxCollatorsAllowed: maxDelegations,
                locale: selectedLocale
            )
        ]).runValidation { [weak self] in
            guard let self else {
                return
            }

            wireframe.showCollatorSelection(from: view, delegate: self)
        }
    }
}

extension ParaStkStakeSetupPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideAssetViewModel()
            provideAmountInputViewModel()
            provideMinStakeViewModel()
            provideFeeViewModel()
            provideRewardsViewModel()
        }
    }
}
