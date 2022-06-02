import Foundation
import SoraFoundation
import BigInt

final class ParaStkStakeSetupPresenter {
    weak var view: ParaStkStakeSetupViewProtocol?
    let wireframe: ParaStkStakeSetupWireframeProtocol
    let interactor: ParaStkStakeSetupInteractorInputProtocol

    let chainAsset: ChainAsset
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let dataValidatingFactory: ParaStkValidatorFactoryProtocol
    let accountDetailsViewModelFactory: ParaStkAccountDetailsViewModelFactoryProtocol

    private var inputResult: AmountInputResult?
    private var fee: BigUInt?
    private var balance: AssetBalance?
    private var minTechStake: BigUInt?
    private var price: PriceData?
    private var rewardCalculator: ParaStakingRewardCalculatorEngineProtocol?

    private var collatorDisplayAddress: DisplayAddress?
    private var collatorMetadata: ParachainStaking.CandidateMetadata?
    private var delegator: ParachainStaking.Delegator?
    private var delegationIdentities: [AccountId: AccountIdentity]?

    private lazy var displayAddressFactory = DisplayAddressViewModelFactory()
    private lazy var aprFormatter = NumberFormatter.positivePercentAPR.localizableResource()

    let logger: LoggerProtocol

    init(
        interactor: ParaStkStakeSetupInteractorInputProtocol,
        wireframe: ParaStkStakeSetupWireframeProtocol,
        dataValidatingFactory: ParaStkValidatorFactoryProtocol,
        chainAsset: ChainAsset,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        accountDetailsViewModelFactory: ParaStkAccountDetailsViewModelFactoryProtocol,
        initialDelegator: ParachainStaking.Delegator?,
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
        self.delegationIdentities = delegationIdentities
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func existingStakeInPlank() -> BigUInt? {
        if let collatorId = try? collatorDisplayAddress?.address.toAccountId() {
            return delegator?.delegations.first(where: { $0.owner == collatorId })?.amount
        } else {
            return nil
        }
    }

    private func balanceMinusFee() -> Decimal {
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
        let balanceDecimal = balance.flatMap { value in
            Decimal.fromSubstrateAmount(
                value.transferable,
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
            priceData: price ?? PriceData.zero
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
            let collatorId = try? collatorDisplayAddress.address.toAccountId()
            let addressModel = displayAddressFactory.createViewModel(from: collatorDisplayAddress)

            let details: TitleWithSubtitleViewModel?

            if let delegation = delegator?.delegations.first(where: { $0.owner == collatorId }) {
                let detailsName = R.string.localizable.commonStakedPrefix(
                    preferredLanguages: selectedLocale.rLanguages
                )

                let stakedDecimal = Decimal.fromSubstrateAmount(
                    delegation.amount,
                    precision: chainAsset.assetDisplayInfo.assetPrecision
                ) ?? 0

                let stakedAmount = balanceViewModelFactory.amountFromValue(stakedDecimal).value(for: selectedLocale)

                details = TitleWithSubtitleViewModel(title: detailsName, subtitle: stakedAmount)
            } else {
                details = nil
            }

            let collatorViewModel = AccountDetailsSelectionViewModel(
                displayAddress: addressModel,
                details: details
            )

            view?.didReceiveCollator(viewModel: collatorViewModel)
        } else {
            view?.didReceiveCollator(viewModel: nil)
        }
    }

    private func refreshFee() {
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

        interactor.estimateFee(
            amount,
            collator: collator,
            collatorDelegationsCount: collatorsDelegationsCount,
            delegationsCount: UInt32(delegationsCount),
            existingBond: existingStakeInPlank()
        )
    }

    private func setupInitialCollator() {
        if
            let lastCollator = delegator?.delegations.last?.owner,
            let address = try? lastCollator.toAddress(using: chainAsset.chain.chainFormat) {
            let name = delegationIdentities?[lastCollator]?.displayName
            collatorDisplayAddress = DisplayAddress(address: address, username: name ?? "")
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
        provideRewardsViewModel()

        interactor.applyCollator(with: collatorId)
    }

    private func startStaking() {
        let precision = chainAsset.assetDisplayInfo.assetPrecision
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee())

        DataValidationRunner(validators: [
            dataValidatingFactory.hasInPlank(
                fee: fee,
                locale: selectedLocale,
                precision: precision,
                onError: { [weak self] in self?.refreshFee() }
            ),
            dataValidatingFactory.canPayFeeAndAmountInPlank(
                balance: balance?.transferable,
                fee: fee,
                spendingAmount: inputAmount,
                precision: precision,
                locale: selectedLocale
            ),
            dataValidatingFactory.canStakeBottomDelegations(
                amount: inputAmount,
                collator: collatorMetadata,
                locale: selectedLocale
            ),
            dataValidatingFactory.hasMinStake(
                amount: inputAmount,
                minTechStake: minTechStake,
                locale: selectedLocale
            ),
            dataValidatingFactory.canStakeTopDelegations(
                amount: inputAmount,
                collator: collatorMetadata,
                locale: selectedLocale
            )
        ]).runValidation { [weak self] in
            guard let collator = self?.collatorDisplayAddress, let amount = inputAmount else {
                return
            }

            self?.wireframe.showConfirmation(
                from: self?.view,
                collator: collator,
                amount: amount,
                initialDelegator: self?.delegator
            )
        }
    }

    private func stakeMore(above _: BigUInt) {
        let precision = chainAsset.assetDisplayInfo.assetPrecision
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee())

        DataValidationRunner(validators: [
            dataValidatingFactory.hasInPlank(
                fee: fee,
                locale: selectedLocale,
                precision: precision,
                onError: { [weak self] in self?.refreshFee() }
            ),
            dataValidatingFactory.canPayFeeAndAmountInPlank(
                balance: balance?.transferable,
                fee: fee,
                spendingAmount: inputAmount,
                precision: precision,
                locale: selectedLocale
            )
        ]).runValidation { [weak self] in
            guard
                let collator = self?.collatorDisplayAddress,
                let amount = inputAmount else {
                return
            }

            self?.wireframe.showConfirmation(
                from: self?.view,
                collator: collator,
                amount: amount,
                initialDelegator: self?.delegator
            )
        }
    }
}

extension ParaStkStakeSetupPresenter: ParaStkStakeSetupPresenterProtocol {
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
    }

    func selectCollator() {
        if let delegator = delegator, !delegator.delegations.isEmpty {
            let delegations = Array(delegator.delegations.reversed())

            let accountDetailsViewModels = accountDetailsViewModelFactory.createViewModels(
                from: delegations,
                identities: delegationIdentities,
                disabled: Set()
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
            stakeMore(above: stakingAmount)
        } else {
            startStaking()
        }
    }
}

extension ParaStkStakeSetupPresenter: ParaStkStakeSetupInteractorOutputProtocol {
    func didReceiveAssetBalance(_ balance: AssetBalance?) {
        self.balance = balance

        provideAssetViewModel()
    }

    func didReceiveRewardCalculator(_ calculator: ParaStakingRewardCalculatorEngineProtocol) {
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

    func didCompleteSetup() {
        refreshFee()
    }

    func didReceiveCollator(metadata: ParachainStaking.CandidateMetadata?) {
        collatorMetadata = metadata

        provideMinStakeViewModel()
        provideRewardsViewModel()
        refreshFee()
    }

    func didReceiveDelegator(_ delegator: ParachainStaking.Delegator?) {
        self.delegator = delegator
    }

    func didReceiveError(_ error: Error) {
        _ = wireframe.present(error: error, from: view, locale: selectedLocale)

        logger.error("Did receive error: \(error)")
    }
}

extension ParaStkStakeSetupPresenter: ParaStkSelectCollatorsDelegate {
    func didSelect(collator: CollatorSelectionInfo) {
        changeCollator(with: collator.accountId, name: collator.identity?.displayName)
    }
}

extension ParaStkStakeSetupPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        guard let delegations = context as? [ParachainStaking.Bond] else {
            return
        }

        let collatorId = delegations[index].owner
        let displayName = delegationIdentities?[collatorId]?.displayName

        changeCollator(with: collatorId, name: displayName)
    }

    func modalPickerDidSelectAction(context _: AnyObject?) {
        wireframe.showCollatorSelection(from: view, delegate: self)
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
