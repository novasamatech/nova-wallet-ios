import Foundation
import BigInt
import Foundation_iOS

final class ParaStkUnstakePresenter {
    weak var view: CollatorStkPartialUnstakeSetupViewProtocol?
    let wireframe: ParaStkUnstakeWireframeProtocol
    let interactor: ParaStkUnstakeInteractorInputProtocol

    let chainAsset: ChainAsset
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let dataValidatingFactory: ParaStkValidatorFactoryProtocol
    let accountDetailsViewModelFactory: CollatorStakingAccountViewModelFactoryProtocol
    let hintViewModelFactory: CollatorStakingHintsViewModelFactoryProtocol

    private(set) var inputResult: AmountInputResult?
    private(set) var fee: ExtrinsicFeeProtocol?
    private(set) var balance: AssetBalance?
    private(set) var minTechStake: BigUInt?
    private(set) var minDelegationAmount: BigUInt?
    private(set) var price: PriceData?

    private(set) var collatorDisplayAddress: DisplayAddress?
    private(set) var collatorMetadata: ParachainStaking.CandidateMetadata?
    private(set) var delegator: ParachainStaking.Delegator?
    private(set) var delegationsDict: [AccountId: ParachainStaking.Bond]?
    private(set) var delegationIdentities: [AccountId: AccountIdentity]?
    private(set) var scheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?
    private(set) var stakingDuration: ParachainStakingDuration?

    let logger: LoggerProtocol

    init(
        interactor: ParaStkUnstakeInteractorInputProtocol,
        wireframe: ParaStkUnstakeWireframeProtocol,
        dataValidatingFactory: ParaStkValidatorFactoryProtocol,
        chainAsset: ChainAsset,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        accountDetailsViewModelFactory: CollatorStakingAccountViewModelFactoryProtocol,
        hintViewModelFactory: CollatorStakingHintsViewModelFactoryProtocol,
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
        self.hintViewModelFactory = hintViewModelFactory
        delegator = initialDelegator
        delegationsDict = initialDelegator?.delegationsDict()
        scheduledRequests = initialScheduledRequests
        self.delegationIdentities = delegationIdentities
        self.logger = logger
        self.localizationManager = localizationManager
    }

    func updateInputResult(_ newValue: AmountInputResult?) {
        inputResult = newValue
    }

    func stakingAmountInPlank() -> BigUInt {
        guard let collatorId = try? collatorDisplayAddress?.address.toAccountId() else {
            return 0
        }

        return delegationsDict?[collatorId]?.amount ?? 0
    }

    func decimalStakingAmount() -> Decimal {
        let amountInPlank = stakingAmountInPlank()
        let precision = chainAsset.assetDisplayInfo.assetPrecision

        return Decimal.fromSubstrateAmount(amountInPlank, precision: precision) ?? 0
    }

    func provideAmountInputViewModel() {
        let inputAmount = inputResult?.absoluteValue(from: decimalStakingAmount())

        let viewModel = balanceViewModelFactory.createBalanceInputViewModel(
            inputAmount
        ).value(for: selectedLocale)

        view?.didReceiveAmount(inputViewModel: viewModel)
    }

    func provideAssetViewModel() {
        let stakedAmount = decimalStakingAmount()
        let inputAmount = inputResult?.absoluteValue(from: stakedAmount) ?? 0
        let viewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            inputAmount,
            balance: stakedAmount,
            priceData: price
        ).value(for: selectedLocale)

        view?.didReceiveAssetBalance(viewModel: viewModel)
    }

    func provideMinStakeViewModel() {
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

        let loadableViewModel: LoadableViewModelState<BalanceViewModelProtocol> = viewModel.map {
            .loaded(value: $0)
        } ?? .loading

        view?.didReceiveMinStake(viewModel: loadableViewModel)
    }

    func provideTransferableViewModel() {
        let viewModel: BalanceViewModelProtocol? = balance.flatMap { balance in
            guard let decimaAmount = Decimal.fromSubstrateAmount(
                balance.transferable,
                precision: chainAsset.assetDisplayInfo.assetPrecision
            ) else {
                return nil
            }

            return balanceViewModelFactory.balanceFromPrice(
                decimaAmount,
                priceData: price
            ).value(for: selectedLocale)
        }

        view?.didReceiveTransferable(viewModel: viewModel)
    }

    func provideFeeViewModel() {
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

    func provideCollatorViewModel() {
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

    func provideHints() {
        var hints: [String] = []

        if let stakingDuration = stakingDuration {
            let durationHint = hintViewModelFactory.unstakeHintForParachainDuration(
                stakingDuration,
                locale: selectedLocale
            )

            hints.append(durationHint)
        }

        hints.append(hintViewModelFactory.unstakingRewards(for: selectedLocale))
        hints.append(hintViewModelFactory.unstakingRedeem(for: selectedLocale))

        view?.didReceiveHints(viewModel: hints)
    }

    func createCallWrapper() -> UnstakeCallWrapper? {
        let inputAmount = inputResult?.absoluteValue(from: decimalStakingAmount()) ?? 0
        let precicion = chainAsset.assetDisplayInfo.assetPrecision

        guard
            let delegationsDict = delegationsDict,
            let minDelegationAmount = minDelegationAmount,
            let amount = inputAmount.toSubstrateAmount(precision: precicion),
            let collator = try? collatorDisplayAddress?.address.toAccountId(),
            let stakedAmount = delegationsDict[collator]?.amount else {
            return nil
        }

        let action: UnstakeCallWrapper.Action = stakedAmount >= minDelegationAmount + amount ?
            .bondLess(amount: amount) : .revoke(amount: stakedAmount)

        return UnstakeCallWrapper(collator: collator, action: action)
    }

    func refreshFee() {
        if let callWrapper = createCallWrapper() {
            fee = nil
            provideFeeViewModel()

            interactor.estimateFee(for: callWrapper)
        }
    }

    func selectInitialCollator() -> AccountId? {
        let unstakingCollators = scheduledRequests?.map(\.collatorId) ?? []
        let unstakingCollatorsSet = Set(unstakingCollators)

        if
            let delegations = delegator?.delegations.filter({ !unstakingCollatorsSet.contains($0.owner) }),
            let collatorId = delegations.max(by: { $0.amount < $1.amount })?.owner,
            let address = try? collatorId.toAddress(using: chainAsset.chain.chainFormat) {
            let name = delegationIdentities?[collatorId]?.displayName
            collatorDisplayAddress = DisplayAddress(address: address, username: name ?? "")

            return collatorId
        } else {
            return nil
        }
    }

    func setupInitialCollator() {
        if let collatorId = selectInitialCollator() {
            interactor.applyCollator(with: collatorId)
            refreshFee()
        }
    }

    func changeCollator(with collatorId: AccountId, name: String?) {
        guard
            let newAddress = try? collatorId.toAddress(using: chainAsset.chain.chainFormat),
            newAddress != collatorDisplayAddress?.address else {
            return
        }

        collatorDisplayAddress = DisplayAddress(address: newAddress, username: name ?? "")

        collatorMetadata = nil

        provideCollatorViewModel()
        provideMinStakeViewModel()
        provideAssetViewModel()

        interactor.applyCollator(with: collatorId)
    }
}

extension ParaStkUnstakePresenter: ParaStkUnstakeInteractorOutputProtocol {
    func didReceiveAssetBalance(_ balance: AssetBalance?) {
        self.balance = balance

        provideTransferableViewModel()
    }

    func didReceivePrice(_ priceData: PriceData?) {
        price = priceData

        provideAssetViewModel()
        provideMinStakeViewModel()
        provideTransferableViewModel()
        provideFeeViewModel()
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
        refreshFee()
    }

    func didReceiveDelegator(_ delegator: ParachainStaking.Delegator?) {
        self.delegator = delegator
        delegationsDict = delegator?.delegationsDict()

        provideCollatorViewModel()
        provideAssetViewModel()

        if let collators = delegator?.collators() {
            interactor.fetchIdentities(for: collators)
        }

        let shouldSetupInitialCollator = scheduledRequests != nil && collatorDisplayAddress == nil

        if shouldSetupInitialCollator {
            setupInitialCollator()
        }

        refreshFee()
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

    func didReceiveMinDelegationAmount(_ amount: BigUInt) {
        minDelegationAmount = amount

        refreshFee()
    }

    func didReceiveScheduledRequests(_ scheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?) {
        let shouldSetupInitialCollator = self.scheduledRequests == nil

        self.scheduledRequests = scheduledRequests ?? []

        if shouldSetupInitialCollator {
            setupInitialCollator()
        }
    }

    func didReceiveStakingDuration(_ stakingDuration: ParachainStakingDuration) {
        self.stakingDuration = stakingDuration

        provideHints()
    }

    func didReceiveError(_ error: Error) {
        _ = wireframe.present(error: error, from: view, locale: selectedLocale)

        logger.error("Did receive error: \(error)")
    }
}

extension ParaStkUnstakePresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideAssetViewModel()
            provideAmountInputViewModel()
            provideMinStakeViewModel()
            provideTransferableViewModel()
            provideHints()
            provideFeeViewModel()
        }
    }
}
