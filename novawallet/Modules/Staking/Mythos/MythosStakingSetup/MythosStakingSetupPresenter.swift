import Foundation
import BigInt
import SubstrateSdk
import Foundation_iOS

final class MythosStakingSetupPresenter {
    weak var view: CollatorStakingSetupViewProtocol?
    let wireframe: MythosStakingSetupWireframeProtocol
    let interactor: MythosStakingSetupInteractorInputProtocol
    let logger: LoggerProtocol

    let chainAsset: ChainAsset
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let accountDetailsViewModelFactory: CollatorStakingAccountViewModelFactoryProtocol
    let dataValidationFactory: MythosStakingValidationFactoryProtocol

    private(set) var inputResult: AmountInputResult?
    private(set) var rewardCalculator: CollatorStakingRewardCalculatorEngineProtocol?
    private(set) var fee: ExtrinsicFeeProtocol?
    private(set) var balance: AssetBalance?
    private(set) var frozenBalance: MythosStakingFrozenBalance?
    private(set) var minStake: BigUInt?
    private(set) var maxCollatorsPerStaker: UInt32?
    private(set) var price: PriceData?
    private(set) var stakingDetails: MythosStakingDetails?
    private(set) var claimableRewards: MythosStakingClaimableRewards?
    private(set) var collatorDisplayAddress: DisplayAddress?
    private(set) var collatorInfo: MythosStakingPallet.CandidateInfo?
    private(set) var delegationIdentities: [AccountId: AccountIdentity]?
    private(set) var currentBlock: BlockNumber?

    private lazy var aprFormatter = NumberFormatter.positivePercentAPR.localizableResource()

    init(
        interactor: MythosStakingSetupInteractorInputProtocol,
        wireframe: MythosStakingSetupWireframeProtocol,
        chainAsset: ChainAsset,
        dataValidationFactory: MythosStakingValidationFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        accountDetailsViewModelFactory: CollatorStakingAccountViewModelFactoryProtocol,
        initialStakingDetails: MythosStakingDetails?,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chainAsset = chainAsset
        self.dataValidationFactory = dataValidationFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.accountDetailsViewModelFactory = accountDetailsViewModelFactory
        stakingDetails = initialStakingDetails
        self.logger = logger
        self.localizationManager = localizationManager
    }
}

private extension MythosStakingSetupPresenter {
    func getCollatorAccount() -> AccountId? {
        try? collatorDisplayAddress?.address.toAccountId(using: chainAsset.chain.chainFormat)
    }

    func getStakingModel() -> MythosStakeModel? {
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee()) ?? 0
        let precision = chainAsset.assetDisplayInfo.assetPrecision

        guard
            let collator = getCollatorAccount(),
            let balanceState = getBalanceState(),
            let amount = inputAmount.toSubstrateAmount(precision: precision),
            let modelAmount = balanceState.deriveStakeAmountModel(for: amount) else {
            return nil
        }

        return MythosStakeModel(amount: modelAmount, collator: collator)
    }

    func getBalanceState() -> MythosStakingBalanceState? {
        MythosStakingBalanceState(
            balance: balance,
            frozenBalance: frozenBalance,
            stakingDetails: stakingDetails,
            currentBlock: currentBlock
        )
    }

    func existingStakeInPlank() -> BigUInt? {
        if let collatorId = getCollatorAccount() {
            return stakingDetails?.stakeDistribution[collatorId]?.stake
        } else {
            return nil
        }
    }

    func allowedAmountToStake() -> BigUInt? {
        getBalanceState()?.stakableAmount()
    }

    func balanceMinusFee() -> Decimal {
        let balanceValue = allowedAmountToStake() ?? 0
        let feeValue = fee?.amountForCurrentAccount ?? 0

        return Decimal.fromSubstrateAmount(
            balanceValue.subtractOrZero(feeValue),
            precision: chainAsset.assetDisplayInfo.assetPrecision
        ) ?? 0
    }

    func provideAmountInputViewModel() {
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee())

        let viewModel = balanceViewModelFactory.createBalanceInputViewModel(
            inputAmount
        ).value(for: selectedLocale)

        view?.didReceiveAmount(inputViewModel: viewModel)
    }

    func provideAmountInputViewModelIfInputRate() {
        guard case .rate = inputResult else {
            return
        }

        provideAmountInputViewModel()
    }

    func provideAssetViewModel() {
        let balanceDecimal = allowedAmountToStake().map { value in
            value.decimal(assetInfo: chainAsset.assetDisplayInfo)
        }

        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee()) ?? 0
        let viewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            inputAmount,
            balance: balanceDecimal ?? 0,
            priceData: price
        ).value(for: selectedLocale)

        view?.didReceiveAssetBalance(viewModel: viewModel)
    }

    func provideMinStakeViewModel() {
        guard let minStakeDecimal = minStake?.decimal(assetInfo: chainAsset.assetDisplayInfo) else {
            return
        }

        let viewModel = balanceViewModelFactory.balanceFromPrice(
            minStakeDecimal,
            priceData: price
        ).value(for: selectedLocale)

        view?.didReceiveMinStake(viewModel: viewModel)
    }

    func provideFeeViewModel() {
        guard let feeDecimal = fee?.amount.decimal(assetInfo: chainAsset.assetDisplayInfo) else {
            view?.didReceiveFee(viewModel: nil)
            return
        }

        let viewModel = balanceViewModelFactory.balanceFromPrice(
            feeDecimal,
            priceData: price
        ).value(for: selectedLocale)

        view?.didReceiveFee(viewModel: viewModel)
    }

    func provideRewardsViewModel() {
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee()) ?? 0

        let amountReturn: Decimal
        let existingStake: Decimal

        if
            let rewardCalculator = rewardCalculator,
            let collatorId = getCollatorAccount() {
            let calculatedReturn = try? rewardCalculator.calculateEarnings(
                amount: 1.0,
                collatorAccountId: collatorId,
                period: .year
            )

            amountReturn = calculatedReturn ?? 0

            let stakeInPlank = existingStakeInPlank() ?? 0
            existingStake = stakeInPlank.decimal(assetInfo: chainAsset.assetDisplayInfo)
        } else {
            let calculatedReturn = rewardCalculator?.calculateMaxReturn(for: .year)
            amountReturn = calculatedReturn ?? 0
            existingStake = 0
        }

        let rewardAmount = (inputAmount + existingStake) * amountReturn

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

    func provideCollatorViewModel() {
        if
            let collatorDisplayAddress = collatorDisplayAddress,
            let collator = getCollatorAccount() {
            let collatorViewModel = accountDetailsViewModelFactory.createCollator(
                from: collatorDisplayAddress,
                stakedAmount: stakingDetails?.stakeDistribution[collator]?.stake,
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

        let amountModel = getBalanceState()?.deriveStakeAmountModel(for: amount) ??
            MythosStakeModel.Amount(toLock: amount)

        fee = nil
        provideFeeViewModel()

        guard let claimableRewards else {
            return
        }

        let collator = getCollatorAccount() ?? AccountId.zeroAccountId(of: chainAsset.chain.accountIdSize)

        let input = MythosStakeModel(
            amount: amountModel,
            collator: collator
        )

        let transactionModel = MythosStakeTransactionModel(
            input: input,
            shouldClaimRewards: claimableRewards.shouldClaim
        )

        interactor.estimateFee(with: transactionModel)
    }

    func setupInitialCollator() {
        let optMaxCollator = stakingDetails?.stakeDistribution
            .max { $0.value.stake < $1.value.stake }?
            .key

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

        collatorInfo = nil

        provideCollatorViewModel()
        provideMinStakeViewModel()
        provideRewardsViewModel()

        interactor.applyCollator(with: collatorId)
    }

    func changeCollator(with collatorId: AccountId, name: String?) {
        guard let newAddress = try? collatorId.toAddress(using: chainAsset.chain.chainFormat) else {
            return
        }

        let displayAddress = DisplayAddress(address: newAddress, username: name ?? "")
        changeCollator(with: displayAddress)
    }

    func getValidationDependencies() -> MythosStakePresenterValidatingDep {
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee()) ?? 0

        return MythosStakePresenterValidatingDep(
            inputAmount: inputAmount,
            allowedAmount: allowedAmountToStake(),
            balance: balance,
            minStake: minStake,
            stakingDetails: stakingDetails,
            selectedCollator: getCollatorAccount(),
            fee: fee,
            maxCollatorsPerStaker: maxCollatorsPerStaker,
            assetDisplayInfo: chainAsset.assetDisplayInfo,
            onFeeRefresh: { [weak self] in
                self?.refreshFee()
            }
        )
    }
}

extension MythosStakingSetupPresenter: CollatorStakingSetupPresenterProtocol {
    func setup() {
        setupInitialCollator()

        provideAmountInputViewModel()

        provideCollatorViewModel()
        provideAssetViewModel()
        provideMinStakeViewModel()
        provideFeeViewModel()

        interactor.setup()

        if let collatorId = getCollatorAccount() {
            interactor.applyCollator(with: collatorId)
        }

        refreshFee()
    }

    func selectCollator() {
        guard let stakingDetails, !stakingDetails.stakeDistribution.isEmpty else {
            wireframe.showCollatorSelection(from: view, delegate: self)
            return
        }

        let delegations = stakingDetails.stakeDistribution.map { pair in
            CollatorStakingAccountViewModelFactory.StakedCollator(
                collator: pair.key,
                amount: pair.value.stake
            )
        }.sorted { $0.amount > $1.amount }

        let accountDetailsViewModels = accountDetailsViewModelFactory.createViewModels(
            from: delegations,
            identities: delegationIdentities,
            disabled: []
        )

        let collatorId = getCollatorAccount()

        let selectedIndex = delegations.firstIndex { $0.collator == collatorId } ?? NSNotFound

        wireframe.showDelegationSelection(
            from: view,
            viewModels: accountDetailsViewModels,
            selectedIndex: selectedIndex,
            delegate: self,
            context: delegations as NSArray
        )
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
        let onSuccess: () -> Void = { [weak self] in
            guard
                let stakingModel = self?.getStakingModel(),
                let collator = self?.collatorDisplayAddress else {
                return
            }

            self?.wireframe.showConfirmation(
                from: self?.view,
                model: MythosStakingConfirmModel(
                    stakingDetails: self?.stakingDetails,
                    collator: collator,
                    stakeModel: stakingModel
                )
            )
        }

        let dependencies = getValidationDependencies()

        if stakingDetails != nil {
            validateStakeMore(
                for: dependencies,
                dataValidationFactory: dataValidationFactory,
                selectedLocale: selectedLocale,
                onSuccess: onSuccess
            )
        } else {
            validateStartStaking(
                for: dependencies,
                dataValidationFactory: dataValidationFactory,
                selectedLocale: selectedLocale,
                onSuccess: onSuccess
            )
        }
    }
}

extension MythosStakingSetupPresenter: CollatorStakingSelectDelegate {
    func didSelect(collator: CollatorStakingSelectionInfoProtocol) {
        changeCollator(with: collator.accountId, name: collator.identity?.displayName)
    }
}

extension MythosStakingSetupPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        guard let delegations = context as? [CollatorStakingAccountViewModelFactory.StakedCollator] else {
            return
        }

        let collatorId = delegations[index].collator

        let displayName = delegationIdentities?[collatorId]?.displayName

        changeCollator(with: collatorId, name: displayName)
    }

    func modalPickerDidSelectAction(context _: AnyObject?) {
        DataValidationRunner(validators: [
            dataValidationFactory.notExceedsMaxCollators(
                currentCollators: stakingDetails?.collatorIds,
                selectedCollator: nil,
                maxCollatorsAllowed: maxCollatorsPerStaker,
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

extension MythosStakingSetupPresenter: MythosStakePresenterValidating {}

extension MythosStakingSetupPresenter: MythosStakingSetupInteractorOutputProtocol {
    func didReceiveAssetBalance(_ balance: AssetBalance?) {
        logger.debug("Balance: \(String(describing: balance))")

        self.balance = balance

        provideAssetViewModel()
        provideAmountInputViewModelIfInputRate()
    }

    func didReceivePrice(_ price: PriceData?) {
        logger.debug("Price: \(String(describing: price))")

        self.price = price

        provideAssetViewModel()
        provideMinStakeViewModel()
        provideFeeViewModel()
        provideRewardsViewModel()
    }

    func didReceiveFee(_ fee: ExtrinsicFeeProtocol) {
        logger.debug("Fee: \(fee)")

        self.fee = fee

        provideFeeViewModel()
        provideAmountInputViewModelIfInputRate()
    }

    func didReceiveRewardCalculator(_ calculator: CollatorStakingRewardCalculatorEngineProtocol) {
        logger.debug("Did receive reward calculator")

        rewardCalculator = calculator

        provideRewardsViewModel()
    }

    func didReceiveMinStakeAmount(_ amount: Balance) {
        logger.debug("Min stake: \(amount)")

        minStake = amount

        provideMinStakeViewModel()
    }

    func didReceiveMaxCollatorsPerStaker(_ maxCollatorsPerStaker: UInt32) {
        logger.debug("Max collators per staker: \(maxCollatorsPerStaker)")

        self.maxCollatorsPerStaker = maxCollatorsPerStaker
    }

    func didReceiveDetails(_ details: MythosStakingDetails?) {
        logger.debug("Staking details: \(String(describing: details))")

        stakingDetails = details

        provideAssetViewModel()
        provideAmountInputViewModelIfInputRate()
        provideCollatorViewModel()
    }

    func didReceiveClaimableRewards(_ claimableRewards: MythosStakingClaimableRewards?) {
        logger.debug("Claimable rewards: \(String(describing: claimableRewards))")

        self.claimableRewards = claimableRewards

        refreshFee()
    }

    func didReceiveDelegationIdentities(_ identities: [AccountId: AccountIdentity]?) {
        logger.debug("Did receive staked collators identities")

        delegationIdentities = identities

        if
            let collatorAddress = collatorDisplayAddress?.address,
            let collatorId = getCollatorAccount() {
            let displayName = identities?[collatorId]?.displayName ?? collatorDisplayAddress?.username

            collatorDisplayAddress = DisplayAddress(address: collatorAddress, username: displayName ?? "")
        }

        provideCollatorViewModel()
    }

    func didReceiveCandidateInfo(_ info: MythosStakingPallet.CandidateInfo?) {
        logger.debug("Candidate info: \(String(describing: info))")

        collatorInfo = info

        provideMinStakeViewModel()
        provideRewardsViewModel()
        refreshFee()
    }

    func didReceivePreferredCollator(_ collator: DisplayAddress?) {
        logger.debug("Preferred Collator: \(String(describing: collator))")

        if collator != nil, collatorDisplayAddress == nil {
            changeCollator(with: collator)
        }
    }

    func didReceiveFrozenBalance(_ frozenBalance: MythosStakingFrozenBalance) {
        logger.debug("Frozen Balance: \(frozenBalance)")

        self.frozenBalance = frozenBalance

        provideAssetViewModel()
        provideAmountInputViewModelIfInputRate()
    }

    func didReceiveBlockNumber(_ blockNumber: BlockNumber) {
        logger.debug("Block number: \(blockNumber)")

        currentBlock = blockNumber

        provideAssetViewModel()
        provideAmountInputViewModelIfInputRate()
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

extension MythosStakingSetupPresenter: Localizable {
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
