import Foundation
import Foundation_iOS

final class MythosStkUnstakeSetupPresenter {
    weak var view: CollatorStkFullUnstakeSetupViewProtocol?
    let wireframe: MythosStkUnstakeSetupWireframeProtocol
    let interactor: MythosStkUnstakeSetupInteractorInputProtocol

    let chainAsset: ChainAsset
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let dataValidatingFactory: MythosStakingValidationFactoryProtocol
    let accountDetailsViewModelFactory: CollatorStakingAccountViewModelFactoryProtocol
    let hintViewModelFactory: CollatorStakingHintsViewModelFactoryProtocol

    private(set) var fee: ExtrinsicFeeProtocol?
    private(set) var balance: AssetBalance?
    private(set) var price: PriceData?
    private(set) var collatorDisplayAddress: DisplayAddress?
    private(set) var stakingDetails: MythosStakingDetails?
    private(set) var delegationIdentities: [AccountId: AccountIdentity]?
    private(set) var claimableRewards: MythosStakingClaimableRewards?
    private(set) var stakingDuration: MythosStakingDuration?
    private(set) var maxUnstakingCollators: UInt32?
    private(set) var releaseQueue: MythosStakingPallet.ReleaseQueue?

    let logger: LoggerProtocol

    init(
        interactor: MythosStkUnstakeSetupInteractorInputProtocol,
        wireframe: MythosStkUnstakeSetupWireframeProtocol,
        chainAsset: ChainAsset,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dataValidatingFactory: MythosStakingValidationFactoryProtocol,
        accountDetailsViewModelFactory: CollatorStakingAccountViewModelFactoryProtocol,
        hintViewModelFactory: CollatorStakingHintsViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chainAsset = chainAsset
        self.balanceViewModelFactory = balanceViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.accountDetailsViewModelFactory = accountDetailsViewModelFactory
        self.hintViewModelFactory = hintViewModelFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }
}

private extension MythosStkUnstakeSetupPresenter {
    func getSelectedCollator() -> AccountId? {
        try? collatorDisplayAddress?.address.toAccountId(
            using: chainAsset.chain.chainFormat
        )
    }

    func stakingAmountInPlank() -> Balance {
        guard let collatorId = getSelectedCollator() else {
            return 0
        }

        return stakingDetails?.stakeDistribution[collatorId]?.stake ?? 0
    }

    func decimalStakingAmount() -> Decimal {
        stakingAmountInPlank().decimal(assetInfo: chainAsset.assetDisplayInfo)
    }

    func provideAmountInputViewModel() {
        let inputAmount = decimalStakingAmount()

        let viewModel = balanceViewModelFactory.createBalanceInputViewModel(
            inputAmount
        ).value(for: selectedLocale)

        view?.didReceiveAmount(inputViewModel: viewModel)
    }

    func provideAssetViewModel() {
        let stakedAmount = decimalStakingAmount()

        let viewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            stakedAmount,
            balance: stakedAmount,
            priceData: price
        ).value(for: selectedLocale)

        view?.didReceiveAssetBalance(viewModel: viewModel)
    }

    func provideMinStakeViewModel() {
        view?.didReceiveMinStake(viewModel: nil)
    }

    func provideTransferableViewModel() {
        let viewModel: BalanceViewModelProtocol? = balance.flatMap { balance in
            let decimaAmount = balance.transferable.decimal(
                assetInfo: chainAsset.assetDisplayInfo
            )

            return balanceViewModelFactory.balanceFromPrice(
                decimaAmount,
                priceData: price
            ).value(for: selectedLocale)
        }

        view?.didReceiveTransferable(viewModel: viewModel)
    }

    func provideFeeViewModel() {
        guard let fee else {
            view?.didReceiveFee(viewModel: nil)
            return
        }

        let feeDecimal = fee.amount.decimal(assetInfo: chainAsset.assetDisplayInfo)

        let viewModel = balanceViewModelFactory.balanceFromPrice(
            feeDecimal,
            priceData: price
        ).value(for: selectedLocale)

        view?.didReceiveFee(viewModel: viewModel)
    }

    func provideCollatorViewModel() {
        if let collatorDisplayAddress = collatorDisplayAddress {
            let collatorViewModel = accountDetailsViewModelFactory.createCollator(
                from: collatorDisplayAddress,
                stakedAmount: stakingAmountInPlank(),
                locale: selectedLocale
            )

            view?.didReceiveCollator(viewModel: collatorViewModel)
        } else {
            view?.didReceiveCollator(viewModel: nil)
        }
    }

    func provideHints() {
        var hints: [String] = []

        if let stakingDuration {
            let durationHint = hintViewModelFactory.unstakeHint(
                for: stakingDuration.unstaking,
                locale: selectedLocale
            )

            hints.append(durationHint)
        }

        hints.append(hintViewModelFactory.unstakingRewards(for: selectedLocale))
        hints.append(hintViewModelFactory.unstakingRedeem(for: selectedLocale))

        view?.didReceiveHints(viewModel: hints)
    }

    func refreshFee() {
        fee = nil
        provideFeeViewModel()

        guard let claimableRewards else {
            return
        }

        let collator = getSelectedCollator() ?? AccountId.zeroAccountId(
            of: chainAsset.chain.accountIdSize
        )

        let model = MythosStkUnstakeModel(
            collator: collator,
            amount: stakingAmountInPlank(),
            shouldClaimRewards: claimableRewards.shouldClaim
        )

        interactor.estimateFee(for: model)
    }

    @discardableResult
    func selectInitialCollator() -> AccountId? {
        if
            let delegations = stakingDetails?.stakeDistribution,
            let collatorId = delegations.max(by: { $0.value.stake < $1.value.stake })?.key,
            let address = try? collatorId.toAddress(using: chainAsset.chain.chainFormat) {
            let name = delegationIdentities?[collatorId]?.displayName
            collatorDisplayAddress = DisplayAddress(address: address, username: name ?? "")

            return collatorId
        } else {
            return nil
        }
    }

    func setupInitialCollator() {
        selectInitialCollator()

        refreshFee()
    }

    func changeCollator(with collatorId: AccountId, name: String?) {
        guard
            let newAddress = try? collatorId.toAddress(using: chainAsset.chain.chainFormat),
            newAddress != collatorDisplayAddress?.address else {
            return
        }

        collatorDisplayAddress = DisplayAddress(address: newAddress, username: name ?? "")

        provideCollatorViewModel()
        provideAssetViewModel()
        provideAmountInputViewModel()
    }

    func updateView() {
        provideAmountInputViewModel()
        provideCollatorViewModel()
        provideAssetViewModel()
        provideMinStakeViewModel()
        provideTransferableViewModel()
        provideHints()
        provideFeeViewModel()
    }

    func createValidationRunner() -> DataValidationRunner {
        DataValidationRunner(validators: [
            dataValidatingFactory.has(
                fee: fee,
                locale: selectedLocale,
                onError: { [weak self] in self?.refreshFee() }
            ),
            dataValidatingFactory.notExceedsMaxUnstakingItems(
                unstakingItemsCount: releaseQueue?.count ?? 0,
                maxUnstakingItemsAllowed: maxUnstakingCollators,
                locale: selectedLocale
            ),
            dataValidatingFactory.canPayFeeInPlank(
                balance: balance?.transferable,
                fee: fee,
                asset: chainAsset.assetDisplayInfo,
                locale: selectedLocale
            )
        ])
    }
}

extension MythosStkUnstakeSetupPresenter: CollatorStkFullUnstakeSetupPresenterProtocol {
    func setup() {
        selectInitialCollator()

        updateView()

        interactor.setup()

        refreshFee()
    }

    func selectCollator() {
        guard let stakingDetails else {
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

        let collatorId = getSelectedCollator()

        let selectedIndex = delegations.firstIndex { $0.collator == collatorId } ?? NSNotFound

        wireframe.showUndelegationSelection(
            from: view,
            viewModels: accountDetailsViewModels,
            selectedIndex: selectedIndex,
            delegate: self,
            context: delegations as NSArray
        )
    }

    func proceed() {
        let validationRunner = createValidationRunner()
        validationRunner.runValidation { [weak self] in
            guard let self, let collatorDisplayAddress else {
                return
            }

            wireframe.showConfirm(from: view, collator: collatorDisplayAddress)
        }
    }
}

extension MythosStkUnstakeSetupPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        guard let delegations = context as? [CollatorStakingAccountViewModelFactory.StakedCollator] else {
            return
        }

        let collatorId = delegations[index].collator

        let displayName = delegationIdentities?[collatorId]?.displayName

        changeCollator(with: collatorId, name: displayName)
    }
}

extension MythosStkUnstakeSetupPresenter: MythosStkUnstakeSetupInteractorOutputProtocol {
    func didReceiveDelegationIdentities(_ identities: [AccountId: AccountIdentity]?) {
        logger.debug("Identities: \(String(describing: identities))")

        delegationIdentities = identities

        if
            let collatorAddress = collatorDisplayAddress?.address,
            let collatorId = getSelectedCollator() {
            let displayName = identities?[collatorId]?.displayName ?? collatorDisplayAddress?.username

            collatorDisplayAddress = DisplayAddress(address: collatorAddress, username: displayName ?? "")
        }

        provideCollatorViewModel()
    }

    func didReceiveBalance(_ balance: AssetBalance?) {
        logger.debug("Balance: \(String(describing: balance))")

        self.balance = balance

        provideTransferableViewModel()
    }

    func didReceivePrice(_ priceData: PriceData?) {
        logger.debug("Price: \(String(describing: priceData))")

        price = priceData

        provideAssetViewModel()
        provideTransferableViewModel()
        provideFeeViewModel()
    }

    func didReceiveStakingDetails(_ stakingDetails: MythosStakingDetails?) {
        logger.debug("Staking details: \(String(describing: stakingDetails))")

        self.stakingDetails = stakingDetails

        let shouldSetupInitialCollator = collatorDisplayAddress == nil

        if shouldSetupInitialCollator {
            setupInitialCollator()
        }

        provideCollatorViewModel()
        provideAssetViewModel()
        provideAmountInputViewModel()

        refreshFee()
    }

    func didReceiveClaimableRewards(_ claimableRewards: MythosStakingClaimableRewards?) {
        logger.debug("Claimable rewards: \(String(describing: claimableRewards))")

        self.claimableRewards = claimableRewards

        refreshFee()
    }

    func didReceiveStakingDuration(_ duration: MythosStakingDuration) {
        logger.debug("Staking duration: \(duration)")

        stakingDuration = duration

        provideHints()
    }

    func didReceiveFee(_ fee: ExtrinsicFeeProtocol) {
        logger.debug("Fee: \(fee)")

        self.fee = fee

        provideFeeViewModel()
    }

    func didReceiveMaxUnstakingCollators(_ maxUnstakingCollators: UInt32) {
        logger.debug("Max unstaking collators: \(maxUnstakingCollators)")

        self.maxUnstakingCollators = maxUnstakingCollators
    }

    func didReceiveReleaseQueue(_ releaseQueue: MythosStakingPallet.ReleaseQueue?) {
        logger.debug("Release queue: \(String(describing: releaseQueue))")

        self.releaseQueue = releaseQueue
    }

    func didReceiveBaseError(_ error: MythosStkUnstakeInteractorError) {
        logger.error("Error: \(error)")

        switch error {
        case .stakingDurationFailed:
            wireframe.presentRequestStatus(
                on: view,
                locale: selectedLocale
            ) { [weak self] in
                self?.interactor.retryStakingDuration()
            }
        case .feeFailed:
            wireframe.presentFeeStatus(
                on: view,
                locale: selectedLocale
            ) { [weak self] in
                self?.refreshFee()
            }
        }
    }
}

extension MythosStkUnstakeSetupPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
