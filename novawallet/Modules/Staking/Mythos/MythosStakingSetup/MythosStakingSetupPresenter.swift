import Foundation
import BigInt
import SubstrateSdk

final class MythosStakingSetupPresenter {
    weak var view: CollatorStakingSetupViewProtocol?
    let wireframe: MythosStakingSetupWireframeProtocol
    let interactor: MythosStakingSetupInteractorInputProtocol
    let logger: LoggerProtocol
    
    let chainAsset: ChainAsset
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let accountDetailsViewModelFactory: MythosStkAccountDetailsViewModelFactoryProtocol
    
    private(set) var inputResult: AmountInputResult?
    private(set) var fee: ExtrinsicFeeProtocol?
    private(set) var balance: AssetBalance?
    private(set) var frozenBalance: MythosStakingFrozenBalance?
    private(set) var minStake: BigUInt?
    private(set) var maxStakersPerCollator: UInt32?
    private(set) var maxCollatorsPerStaker: UInt32?
    private(set) var price: PriceData?
    private(set) var stakingDetails: MythosStakingDetails?
    private(set) var collatorDisplayAddress: DisplayAddress?
    private(set) var collatorInfo: MythosStakingPallet.CandidateInfo?
    private(set) var currentBlock: BlockNumber?

    private lazy var aprFormatter = NumberFormatter.positivePercentAPR.localizableResource()

    init(
        interactor: MythosStakingSetupInteractorInputProtocol,
        wireframe: MythosStakingSetupWireframeProtocol,
        chainAsset: ChainAsset,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chainAsset = chainAsset
        self.balanceViewModelFactory = balanceViewModelFactory
        self.logger = logger
    }
}

private extension MythosStakingSetupPresenter {
    private func getCollatorAccount() -> AccountId? {
        try? collatorDisplayAddress?.address.toAccountId(using: chainAsset.chain.chainFormat)
    }
    
    private func getBalanceState() -> MythosStakingBalanceState? {
        MythosStakingBalanceState(
            balance: balance,
            frozenBalance: frozenBalance,
            stakingDetails: stakingDetails,
            currentBlock: currentBlock
        )
    }
    
    private func existingStakeInPlank() -> BigUInt? {
        if let collatorId = try? collatorDisplayAddress?.address.toAccountId() {
            return stakingDetails?.stakeDistribution[collatorId]?.stake
        } else {
            return nil
        }
    }
    
    private func allowedAmountToStake() -> BigUInt? {
        getBalanceState()?.stakableAmount()
    }
    
    private func balanceMinusFee() -> Decimal {
        let balanceValue = allowedAmountToStake() ?? 0
        let feeValue = fee?.amountForCurrentAccount ?? 0

        return Decimal.fromSubstrateAmount(
            balanceValue.subtractOrZero(feeValue),
            precision: chainAsset.assetDisplayInfo.assetPrecision
        ) ?? 0
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
        guard let minStakeDecimal = minStake?.decimal(assetInfo: chainAsset.assetDisplayInfo) else {
            return
        }
        
        let viewModel = balanceViewModelFactory.balanceFromPrice(
            minStakeDecimal,
            priceData: price
        ).value(for: selectedLocale)

        view?.didReceiveMinStake(viewModel: viewModel)
    }

    private func provideFeeViewModel() {
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

    private func provideRewardsViewModel() {
        // TODO: Fix when reward calculator is available

        let balanceViewModel = balanceViewModelFactory.balanceFromPrice(
            0,
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

        let stakeModel = MythosStakeModel(
            amount: amountModel,
            collator: getCollatorAccount() ?? AccountId.zeroAccountId(
                of: chainAsset.chain.accountIdSize
            )
        )
        
        interactor.estimateFee(with: stakeModel)
    }
}

extension MythosStakingSetupPresenter: CollatorStakingSetupPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func selectCollator() {}
    func updateAmount(_: Decimal?) {}
    func selectAmountPercentage(_: Float) {}
    func proceed() {}
}

extension MythosStakingSetupPresenter: MythosStakingSetupInteractorOutputProtocol {
    func didReceiveAssetBalance(_ balance: AssetBalance?) {
        logger.debug("Balance: \(String(describing: balance))")
        
        self.balance = balance
    }

    func didReceivePrice(_ price: PriceData?) {
        logger.debug("Price: \(String(describing: price))")
        
        self.price = price
    }

    func didReceiveFee(_ fee: ExtrinsicFeeProtocol) {
        logger.debug("Fee: \(fee)")
        
        self.fee = fee
    }

    func didReceiveMinStakeAmount(_ amount: BigUInt) {
        logger.debug("Min stake: \(amount)")
        
        self.minStake = amount
    }

    func didReceiveMaxStakersPerCollator(_ maxStakersPerCollator: UInt32) {
        logger.debug("Max stakers per collator: \(maxStakersPerCollator)")
        
        self.maxStakersPerCollator = maxStakersPerCollator
    }

    func didReceiveMaxCollatorsPerStaker(_ maxCollatorsPerStaker: UInt32) {
        logger.debug("Max collators per staker: \(maxCollatorsPerStaker)")
        
        self.maxCollatorsPerStaker = maxCollatorsPerStaker
    }

    func didReceiveDetails(_ details: MythosStakingDetails?) {
        logger.debug("Max collators per staker: \(String(describing: details))")
        
        self.stakingDetails = details
    }

    func didReceiveCandidateInfo(_ info: MythosStakingPallet.CandidateInfo?) {
        logger.debug("Candidate info: \(String(describing: info))")
        
        self.collatorInfo = collatorInfo
    }

    func didReceivePreferredCollator(_ collator: DisplayAddress?) {
        logger.debug("Preferred Collator: \(String(describing: collator))")
        
        self.collatorDisplayAddress = collator
    }

    func didReceiveFrozenBalance(_ frozenBalance: MythosStakingFrozenBalance) {
        logger.debug("Frozen Balance: \(frozenBalance)")
        
        self.frozenBalance = frozenBalance
    }

    func didReceiveError(_ error: MythosStakingSetupError) {
        logger.debug("Error: \(error)")
    }
}
