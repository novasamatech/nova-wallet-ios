import BigInt
import Foundation
import Foundation_iOS

final class SubtensorUnstakeSetupPresenter {
    weak var view: CollatorStkPartialUnstakeSetupViewProtocol?
    let wireframe: SubtensorUnstakeSetupWireframeProtocol
    let interactor: SubtensorUnstakeSetupInteractorInputProtocol
    let logger: LoggerProtocol

    let chainAsset: ChainAsset
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let accountDetailsViewModelFactory: CollatorStakingAccountViewModelFactoryProtocol
    let dataValidationFactory: SubtensorStakingValidationFactoryProtocol

    private(set) var inputResult: AmountInputResult?
    private(set) var fee: ExtrinsicFeeProtocol?
    private(set) var balance: AssetBalance?
    private(set) var price: PriceData?
    private(set) var positionsState: Multistaking.SubtensorStakingState?
    private(set) var claimable: SubtensorRootClaimable?
    private(set) var preflight: SubtensorStakingPreflight?
    private(set) var delegateDisplayAddress: DisplayAddress?
    private(set) var delegateIdentities: [AccountId: AccountIdentity]?
    private(set) var currentBlock: BlockNumber?

    init(
        interactor: SubtensorUnstakeSetupInteractorInputProtocol,
        wireframe: SubtensorUnstakeSetupWireframeProtocol,
        chainAsset: ChainAsset,
        dataValidationFactory: SubtensorStakingValidationFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        accountDetailsViewModelFactory: CollatorStakingAccountViewModelFactoryProtocol,
        initialPosition: SubtensorStakingPosition?,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chainAsset = chainAsset
        self.dataValidationFactory = dataValidationFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.accountDetailsViewModelFactory = accountDetailsViewModelFactory
        self.logger = logger

        if
            let initialPosition,
            let address = try? initialPosition.hotkey.toAddress(using: chainAsset.chain.chainFormat) {
            delegateDisplayAddress = DisplayAddress(address: address, username: "")
        }

        self.localizationManager = localizationManager
    }
}

private extension SubtensorUnstakeSetupPresenter {
    func getDelegateAccount() -> AccountId? {
        try? delegateDisplayAddress?.address.toAccountId(using: chainAsset.chain.chainFormat)
    }

    func rootPositions() -> [SubtensorStakingPosition] {
        (positionsState?.positions ?? []).filter { $0.netuid == SubtensorStakingPallet.rootNetuid }
    }

    func stakedAmountInPlank() -> Balance {
        guard let hotkey = getDelegateAccount() else {
            return 0
        }

        return rootPositions().first { $0.hotkey == hotkey }?.stakeAlpha ?? 0
    }

    func stakedAmountDecimal() -> Decimal {
        stakedAmountInPlank().decimal(assetInfo: chainAsset.assetDisplayInfo)
    }

    func inputAmountInPlank() -> Balance? {
        let inputAmount = inputResult?.absoluteValue(from: stakedAmountDecimal()) ?? 0

        let amount = inputAmount.toSubstrateAmount(
            precision: chainAsset.assetDisplayInfo.assetPrecision
        )

        return amount.map { min($0, stakedAmountInPlank()) }
    }

    func isFullUnstake() -> Bool {
        guard let inputResult else {
            return false
        }

        if case let .rate(value) = inputResult, value >= 1 {
            return true
        }

        return inputAmountInPlank() == stakedAmountInPlank() && stakedAmountInPlank() > 0
    }

    func getUnstakeModel() -> SubtensorUnstakeModel? {
        guard let hotkey = getDelegateAccount(), let amount = inputAmountInPlank() else {
            return nil
        }

        return SubtensorUnstakeModel(
            hotkey: hotkey,
            netuid: SubtensorStakingPallet.rootNetuid,
            amount: amount,
            isFullUnstake: isFullUnstake()
        )
    }

    func claimablePayout() -> Balance? {
        guard let hotkey = getDelegateAccount() else {
            return nil
        }

        return claimable?.payout(for: hotkey)
    }

    func provideAmountInputViewModel() {
        let inputAmount = inputResult?.absoluteValue(from: stakedAmountDecimal())

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
        let stakedDecimal = stakedAmountDecimal()

        let inputAmount = inputResult?.absoluteValue(from: stakedDecimal) ?? 0

        let viewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            inputAmount,
            balance: stakedDecimal,
            priceData: price
        ).value(for: selectedLocale)

        view?.didReceiveAssetBalance(viewModel: viewModel)
    }

    func provideMinStakeViewModel() {
        view?.didReceiveMinStake(viewModel: nil)
    }

    func provideTransferableViewModel() {
        let viewModel: BalanceViewModelProtocol? = balance.map { value in
            let transferableDecimal = value.transferable.decimal(
                assetInfo: chainAsset.assetDisplayInfo
            )

            return balanceViewModelFactory.balanceFromPrice(
                transferableDecimal,
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
        ).value(for: selectedLocale).approximatelyForSubtensorFee()

        view?.didReceiveFee(viewModel: viewModel)
    }

    func provideDelegateViewModel() {
        if let delegateDisplayAddress {
            let viewModel = accountDetailsViewModelFactory.createCollator(
                from: delegateDisplayAddress,
                stakedAmount: stakedAmountInPlank(),
                locale: selectedLocale
            )

            view?.didReceiveCollator(viewModel: viewModel)
        } else {
            view?.didReceiveCollator(viewModel: nil)
        }
    }

    func provideHints() {
        let hints = [
            R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.stakingSubtensorHintUnstakeInstant()
        ]

        view?.didReceiveHints(viewModel: hints)
    }

    func refreshFee() {
        fee = nil
        provideFeeViewModel()

        let hotkey = getDelegateAccount() ?? AccountId.zeroAccountId(
            of: chainAsset.chain.accountIdSize
        )

        let model = SubtensorUnstakeModel(
            hotkey: hotkey,
            netuid: SubtensorStakingPallet.rootNetuid,
            amount: inputAmountInPlank() ?? 0,
            isFullUnstake: isFullUnstake()
        )

        interactor.estimateFee(for: .unstake(model))
    }

    func setupInitialDelegate() {
        guard delegateDisplayAddress == nil else {
            return
        }

        let optMaxPosition = rootPositions().max { $0.stakeAlpha < $1.stakeAlpha }

        guard
            let position = optMaxPosition,
            let address = try? position.hotkey.toAddress(using: chainAsset.chain.chainFormat) else {
            return
        }

        let name = delegateIdentities?[position.hotkey]?.displayName
        delegateDisplayAddress = DisplayAddress(address: address, username: name ?? "")
    }

    func changeDelegate(with hotkey: AccountId, name: String?) {
        guard
            let newAddress = try? hotkey.toAddress(using: chainAsset.chain.chainFormat),
            newAddress != delegateDisplayAddress?.address else {
            return
        }

        delegateDisplayAddress = DisplayAddress(address: newAddress, username: name ?? "")
        preflight = nil

        provideDelegateViewModel()
        provideAssetViewModel()
        provideAmountInputViewModel()

        interactor.applyDelegate(with: hotkey)
        refreshFee()
    }

    func updateView() {
        provideAmountInputViewModel()
        provideDelegateViewModel()
        provideAssetViewModel()
        provideMinStakeViewModel()
        provideTransferableViewModel()
        provideHints()
        provideFeeViewModel()
    }

    func getValidationDependencies() -> SubtensorUnstakeValidatingDep {
        SubtensorUnstakeValidatingDep(
            amount: inputAmountInPlank(),
            stakedAmount: stakedAmountInPlank(),
            isFullUnstake: isFullUnstake(),
            balance: balance,
            fee: fee,
            preflight: preflight,
            claimablePayout: claimablePayout(),
            currentBlock: currentBlock,
            blockTime: chainAsset.chain.defaultBlockTimeMillis ?? SubtensorStakingFlowConstants.blockTimeMillis,
            assetDisplayInfo: chainAsset.assetDisplayInfo,
            onFeeRefresh: { [weak self] in
                self?.refreshFee()
            },
            onPreflightRefresh: { [weak self] in
                guard let self, let hotkey = getDelegateAccount() else {
                    return
                }

                interactor.applyDelegate(with: hotkey)
            }
        )
    }
}

extension SubtensorUnstakeSetupPresenter: CollatorStkPartialUnstakeSetupPresenterProtocol {
    func setup() {
        setupInitialDelegate()

        updateView()

        interactor.setup()

        if let hotkey = getDelegateAccount() {
            interactor.applyDelegate(with: hotkey)
        }

        refreshFee()
    }

    func selectCollator() {
        let positions = rootPositions()

        guard !positions.isEmpty else {
            return
        }

        let stakedDelegates = positions.map { position in
            CollatorStakingAccountViewModelFactory.StakedCollator(
                collator: position.hotkey,
                amount: position.stakeAlpha
            )
        }.sorted { $0.amount > $1.amount }

        let viewModels = accountDetailsViewModelFactory.createViewModels(
            from: stakedDelegates,
            identities: delegateIdentities,
            disabled: []
        )

        let selectedDelegate = getDelegateAccount()

        let selectedIndex = stakedDelegates.firstIndex { $0.collator == selectedDelegate } ?? NSNotFound

        wireframe.showUndelegationSelection(
            from: view,
            viewModels: viewModels,
            selectedIndex: selectedIndex,
            delegate: self,
            context: stakedDelegates as NSArray,
            statics: .subtensorValidator
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

    func proceed() {
        validateUnstake(
            for: getValidationDependencies(),
            dataValidationFactory: dataValidationFactory,
            selectedLocale: selectedLocale
        ) { [weak self] in
            guard
                let self,
                let unstakeModel = getUnstakeModel(),
                let delegate = delegateDisplayAddress else {
                return
            }

            wireframe.showConfirm(
                from: view,
                model: SubtensorUnstakeConfirmModel(
                    delegate: delegate,
                    unstakeModel: unstakeModel
                )
            )
        }
    }
}

extension SubtensorUnstakeSetupPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        guard let delegates = context as? [CollatorStakingAccountViewModelFactory.StakedCollator] else {
            return
        }

        let hotkey = delegates[index].collator

        changeDelegate(with: hotkey, name: delegateIdentities?[hotkey]?.displayName)
    }
}

extension SubtensorUnstakeSetupPresenter: SubtensorUnstakePresenterValidating {}

extension SubtensorUnstakeSetupPresenter: SubtensorUnstakeSetupInteractorOutputProtocol {
    func didReceiveAssetBalance(_ balance: AssetBalance?) {
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

    func didReceiveFee(_ fee: ExtrinsicFeeProtocol) {
        logger.debug("Fee: \(fee)")

        self.fee = fee

        provideFeeViewModel()
    }

    func didReceivePositions(_ state: Multistaking.SubtensorStakingState?) {
        logger.debug("Positions: \(String(describing: state))")

        positionsState = state

        let shouldSetupInitialDelegate = delegateDisplayAddress == nil

        if shouldSetupInitialDelegate {
            setupInitialDelegate()

            if let hotkey = getDelegateAccount() {
                interactor.applyDelegate(with: hotkey)
            }
        }

        provideDelegateViewModel()
        provideAssetViewModel()
        provideAmountInputViewModelIfInputRate()

        refreshFee()
    }

    func didReceiveClaimable(_ claimable: SubtensorRootClaimable?) {
        logger.debug("Claimable: \(String(describing: claimable))")

        self.claimable = claimable
    }

    func didReceiveBlockNumber(_ blockNumber: BlockNumber) {
        logger.debug("Block number: \(blockNumber)")

        currentBlock = blockNumber
    }

    func didReceivePreflight(_ preflight: SubtensorStakingPreflight) {
        logger.debug("Preflight: \(preflight)")

        self.preflight = preflight
    }

    func didReceiveExistentialDeposit(_ deposit: Balance) {
        logger.debug("Existential deposit: \(deposit)")
    }

    func didReceiveDelegateIdentities(_ identities: [AccountId: AccountIdentity]?) {
        logger.debug("Did receive delegate identities")

        delegateIdentities = identities

        if
            let delegateAddress = delegateDisplayAddress?.address,
            let hotkey = getDelegateAccount(),
            let displayName = identities?[hotkey]?.displayName {
            delegateDisplayAddress = DisplayAddress(address: delegateAddress, username: displayName)
        }

        provideDelegateViewModel()
    }

    func didReceiveBaseError(_ error: SubtensorStakingBaseError) {
        logger.error("Error: \(error)")

        switch error {
        case .feeFailed:
            wireframe.presentFeeStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.refreshFee()
            }
        case .preflightFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                guard let self, let hotkey = getDelegateAccount() else {
                    return
                }

                interactor.applyDelegate(with: hotkey)
            }
        }
    }
}

extension SubtensorUnstakeSetupPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
