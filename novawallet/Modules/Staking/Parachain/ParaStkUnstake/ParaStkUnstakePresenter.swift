import Foundation
import BigInt
import SoraFoundation

final class ParaStkUnstakePresenter {
    weak var view: ParaStkUnstakeViewProtocol?
    let wireframe: ParaStkUnstakeWireframeProtocol
    let interactor: ParaStkUnstakeInteractorInputProtocol

    let chainAsset: ChainAsset
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let dataValidatingFactory: ParaStkValidatorFactoryProtocol
    let accountDetailsViewModelFactory: ParaStkAccountDetailsViewModelFactoryProtocol
    let hintViewModelFactory: ParaStkHintsViewModelFactoryProtocol

    private(set) var inputResult: AmountInputResult?
    private(set) var fee: BigUInt?
    private(set) var balance: AssetBalance?
    private(set) var minTechStake: BigUInt?
    private(set) var minDelegationAmount: BigUInt?
    private(set) var maxDelegations: UInt32?
    private(set) var price: PriceData?
    private(set) var rewardCalculator: ParaStakingRewardCalculatorEngineProtocol?

    private(set) var collatorDisplayAddress: DisplayAddress?
    private(set) var collatorMetadata: ParachainStaking.CandidateMetadata?
    private(set) var delegator: ParachainStaking.Delegator?
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
        accountDetailsViewModelFactory: ParaStkAccountDetailsViewModelFactoryProtocol,
        hintViewModelFactory: ParaStkHintsViewModelFactoryProtocol,
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
        scheduledRequests = initialScheduledRequests
        self.delegationIdentities = delegationIdentities
        self.logger = logger
        self.localizationManager = localizationManager
    }

    func balanceMinusFee() -> Decimal {
        let balanceValue = balance?.transferable ?? 0
        let feeValue = fee ?? 0

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
        let balanceDecimal = delegator.flatMap { value in
            Decimal.fromSubstrateAmount(
                value.staked,
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

    private func provideTransferableViewModel() {
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

    private func provideFeeViewModel() {
        let optFeeDecimal = fee.flatMap { value in
            Decimal.fromSubstrateAmount(
                value,
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

    private func provideHints() {
        var hints: [String] = []

        if let stakingDuration = stakingDuration {
            hints.append(hintViewModelFactory.unstakeHint(for: stakingDuration, locale: selectedLocale))
        }

        hints.append(hintViewModelFactory.unstakingRewards(for: selectedLocale))
        hints.append(hintViewModelFactory.unstakingRedeem(for: selectedLocale))

        view?.didReceiveHints(viewModel: hints)
    }

    private func createCallWrapper() -> UnstakeCallWrapper? {
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee()) ?? 0
        let precicion = chainAsset.assetDisplayInfo.assetPrecision

        guard
            let delegator = delegator,
            let minDelegationAmount = minDelegationAmount,
            let amount = inputAmount.toSubstrateAmount(precision: precicion) else {
            return nil
        }

        let optCollator = try? collatorDisplayAddress?.address.toAccountId()
        let collator = optCollator ?? AccountId.dummyAccountId(of: chainAsset.chain.accountIdSize)

        let callAmount: BigUInt?

        if let stakedAmount = delegator.delegations.first(where: { $0.owner == collator })?.amount {
            callAmount = stakedAmount >= minDelegationAmount + amount ? amount : nil
        } else {
            callAmount = 0
        }

        return UnstakeCallWrapper(collator: collator, amount: callAmount)
    }

    private func refreshFee() {
        if let callWrapper = createCallWrapper() {
            fee = nil
            provideFeeViewModel()

            interactor.estimateFee(for: callWrapper)
        }
    }

    private func selectInitialCollator() -> AccountId? {
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

    private func setupInitialCollator() {
        if let collatorId = selectInitialCollator() {
            interactor.applyCollator(with: collatorId)
            refreshFee()
        }
    }

    private func changeCollator(with collatorId: AccountId, name: String?) {
        guard
            let newAddress = try? collatorId.toAddress(using: chainAsset.chain.chainFormat),
            newAddress != collatorDisplayAddress?.address else {
            return
        }

        collatorDisplayAddress = DisplayAddress(address: newAddress, username: name ?? "")

        collatorMetadata = nil

        provideCollatorViewModel()
        provideMinStakeViewModel()

        interactor.applyCollator(with: collatorId)
    }
}

extension ParaStkUnstakePresenter: ParaStkUnstakePresenterProtocol {
    func setup() {
        let optCollatorId = selectInitialCollator()

        provideAmountInputViewModel()

        provideCollatorViewModel()
        provideAssetViewModel()
        provideMinStakeViewModel()
        provideTransferableViewModel()
        provideHints()
        provideFeeViewModel()

        interactor.setup()

        if let collatorId = optCollatorId {
            interactor.applyCollator(with: collatorId)
        }

        refreshFee()
    }

    func selectCollator() {
        guard
            let delegator = delegator,
            let disabledCollators = scheduledRequests?.map(\.collatorId) else {
            return
        }

        let delegations = delegator.delegations.sorted { $0.amount > $1.amount }

        let accountDetailsViewModels = accountDetailsViewModelFactory.createViewModels(
            from: delegations,
            identities: delegationIdentities,
            disabled: Set(disabledCollators)
        )

        let collatorId = try? collatorDisplayAddress?.address.toAccountId()

        let selectedIndex = delegations.firstIndex { $0.owner == collatorId } ?? NSNotFound

        wireframe.showUnstakingCollatorSelection(
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
    }

    func selectAmountPercentage(_ percentage: Float) {
        inputResult = .rate(Decimal(Double(percentage)))

        provideAmountInputViewModel()

        refreshFee()
        provideAssetViewModel()
    }

    func proceed() {}
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

    func didReceiveFee(_ result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(dispatchInfo):
            fee = BigUInt(dispatchInfo.fee)

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

extension ParaStkUnstakePresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        guard
            let delegations = context as? [ParachainStaking.Bond],
            let disabledCollators = scheduledRequests?.map(\.collatorId) else {
            return
        }

        let collatorId = delegations[index].owner

        if !disabledCollators.contains(collatorId) {
            let displayName = delegationIdentities?[collatorId]?.displayName
            changeCollator(with: collatorId, name: displayName)
        } else {
            let title = R.string.localizable.parastkCantUnstakeTitle(
                preferredLanguages: selectedLocale.rLanguages
            )

            let message = R.string.localizable.parastkCantUnstakeMessage(
                preferredLanguages: selectedLocale.rLanguages
            )

            let close = R.string.localizable.commonClose(preferredLanguages: selectedLocale.rLanguages)

            wireframe.present(message: message, title: title, closeAction: close, from: view)
        }
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
