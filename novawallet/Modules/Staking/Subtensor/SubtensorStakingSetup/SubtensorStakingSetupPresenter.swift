import BigInt
import Foundation
import Foundation_iOS

final class SubtensorStakingSetupPresenter {
    weak var view: CollatorStakingSetupViewProtocol?
    let wireframe: SubtensorStakingSetupWireframeProtocol
    let interactor: SubtensorStakingSetupInteractorInputProtocol
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
    private(set) var preflight: SubtensorStakingPreflight?
    private(set) var existentialDeposit: Balance?
    private(set) var delegateDisplayAddress: DisplayAddress?
    private(set) var delegateTake: UInt16?
    private(set) var delegateIdentities: [AccountId: AccountIdentity]?
    private(set) var currentBlock: BlockNumber?

    init(
        interactor: SubtensorStakingSetupInteractorInputProtocol,
        wireframe: SubtensorStakingSetupWireframeProtocol,
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

private extension SubtensorStakingSetupPresenter {
    func getDelegateAccount() -> AccountId? {
        try? delegateDisplayAddress?.address.toAccountId(using: chainAsset.chain.chainFormat)
    }

    func rootPositions() -> [SubtensorStakingPosition] {
        (positionsState?.positions ?? []).filter { $0.netuid == SubtensorStakingPallet.rootNetuid }
    }

    func existingStakeInPlank() -> Balance? {
        guard let hotkey = getDelegateAccount() else {
            return nil
        }

        return rootPositions().first { $0.hotkey == hotkey }?.stakeAlpha
    }

    func balanceMinusFee() -> Decimal {
        let balanceValue = balance?.transferable ?? 0
        let feeValue = fee?.amountForCurrentAccount ?? 0

        return Decimal.fromSubstrateAmount(
            balanceValue.subtractOrZero(feeValue),
            precision: chainAsset.assetDisplayInfo.assetPrecision
        ) ?? 0
    }

    func inputAmountInPlank() -> Balance? {
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee()) ?? 0

        return inputAmount.toSubstrateAmount(
            precision: chainAsset.assetDisplayInfo.assetPrecision
        )
    }

    func getStakeModel() -> SubtensorStakeModel? {
        guard
            let hotkey = getDelegateAccount(),
            let amount = inputAmountInPlank() else {
            return nil
        }

        return SubtensorStakeModel(
            hotkey: hotkey,
            netuid: SubtensorStakingPallet.rootNetuid,
            amount: amount
        )
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
        let balanceDecimal = (balance?.transferable ?? 0).decimal(
            assetInfo: chainAsset.assetDisplayInfo
        )

        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee()) ?? 0

        let viewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            inputAmount,
            balance: balanceDecimal,
            priceData: price
        ).value(for: selectedLocale)

        view?.didReceiveAssetBalance(viewModel: viewModel)
    }

    func provideMinStakeViewModel() {
        guard let minStakeDecimal = preflight?.minStake.decimal(
            assetInfo: chainAsset.assetDisplayInfo
        ) else {
            view?.didReceiveMinStake(viewModel: nil)
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
        ).value(for: selectedLocale).approximatelyForSubtensorFee()

        view?.didReceiveFee(viewModel: viewModel)
    }

    func provideDelegateViewModel() {
        if let delegateDisplayAddress {
            let viewModel = accountDetailsViewModelFactory.createCollator(
                from: delegateDisplayAddress,
                stakedAmount: existingStakeInPlank(),
                locale: selectedLocale
            )

            view?.didReceiveCollator(viewModel: viewModel)
        } else {
            view?.didReceiveCollator(viewModel: nil)
        }
    }

    func refreshFee() {
        fee = nil
        provideFeeViewModel()

        let hotkey = getDelegateAccount() ?? AccountId.zeroAccountId(
            of: chainAsset.chain.accountIdSize
        )

        let model = SubtensorStakeModel(
            hotkey: hotkey,
            netuid: SubtensorStakingPallet.rootNetuid,
            amount: inputAmountInPlank() ?? 0
        )

        interactor.estimateFee(for: .stake(model))
    }

    func changeDelegate(with accountId: AccountId, name: String?, take: UInt16?) {
        guard
            let newAddress = try? accountId.toAddress(using: chainAsset.chain.chainFormat),
            newAddress != delegateDisplayAddress?.address else {
            return
        }

        delegateDisplayAddress = DisplayAddress(address: newAddress, username: name ?? "")
        delegateTake = take
        preflight = nil

        provideDelegateViewModel()
        provideMinStakeViewModel()

        interactor.applyDelegate(with: accountId)
        refreshFee()
    }

    func getValidationDependencies() -> SubtensorStakeValidatingDep {
        SubtensorStakeValidatingDep(
            amount: inputAmountInPlank(),
            balance: balance,
            fee: fee,
            existentialDeposit: existentialDeposit,
            preflight: preflight,
            netuid: SubtensorStakingPallet.rootNetuid,
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

extension SubtensorStakingSetupPresenter: CollatorStakingSetupPresenterProtocol {
    func setup() {
        provideAmountInputViewModel()
        provideDelegateViewModel()
        provideAssetViewModel()
        provideMinStakeViewModel()
        provideFeeViewModel()

        interactor.setup()

        if let hotkey = getDelegateAccount() {
            interactor.applyDelegate(with: hotkey)
        }

        refreshFee()
    }

    func selectCollator() {
        let positions = rootPositions()

        guard !positions.isEmpty else {
            wireframe.showDelegateSelection(from: view, delegate: self)
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

        wireframe.showDelegationSelection(
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
        let dependencies = getValidationDependencies()

        validateStake(
            for: dependencies,
            dataValidationFactory: dataValidationFactory,
            selectedLocale: selectedLocale
        ) { [weak self] in
            guard
                let self,
                let stakeModel = getStakeModel(),
                let delegate = delegateDisplayAddress else {
                return
            }

            wireframe.showConfirmation(
                from: view,
                model: SubtensorStakingConfirmModel(
                    delegate: delegate,
                    delegateTake: delegateTake ?? preflight?.delegateTake,
                    stakeModel: stakeModel,
                    isStakeMore: existingStakeInPlank() != nil
                )
            )
        }
    }
}

extension SubtensorStakingSetupPresenter: CollatorStakingSelectDelegate {
    func didSelect(collator: CollatorStakingSelectionInfoProtocol) {
        let take = (collator as? SubtensorDelegateSelectionInfo)?.take

        changeDelegate(
            with: collator.accountId,
            name: collator.identity?.displayName,
            take: take
        )
    }
}

extension SubtensorStakingSetupPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        guard let delegates = context as? [CollatorStakingAccountViewModelFactory.StakedCollator] else {
            return
        }

        let hotkey = delegates[index].collator

        changeDelegate(
            with: hotkey,
            name: delegateIdentities?[hotkey]?.displayName,
            take: nil
        )
    }

    func modalPickerDidSelectAction(context _: AnyObject?) {
        wireframe.showDelegateSelection(from: view, delegate: self)
    }
}

extension SubtensorStakingSetupPresenter: SubtensorStakePresenterValidating {}

extension SubtensorStakingSetupPresenter: SubtensorStakingSetupInteractorOutputProtocol {
    func didReceiveAssetBalance(_ balance: AssetBalance?) {
        logger.debug("Balance: \(String(describing: balance))")

        self.balance = balance

        provideAssetViewModel()
        provideAmountInputViewModelIfInputRate()
    }

    func didReceivePrice(_ priceData: PriceData?) {
        logger.debug("Price: \(String(describing: priceData))")

        price = priceData

        provideAssetViewModel()
        provideMinStakeViewModel()
        provideFeeViewModel()
    }

    func didReceiveFee(_ fee: ExtrinsicFeeProtocol) {
        logger.debug("Fee: \(fee)")

        self.fee = fee

        provideFeeViewModel()
        provideAmountInputViewModelIfInputRate()
    }

    func didReceivePositions(_ state: Multistaking.SubtensorStakingState?) {
        logger.debug("Positions: \(String(describing: state))")

        positionsState = state

        provideDelegateViewModel()
        provideAssetViewModel()
        provideAmountInputViewModelIfInputRate()
    }

    func didReceiveClaimable(_ claimable: SubtensorRootClaimable?) {
        logger.debug("Claimable: \(String(describing: claimable))")
    }

    func didReceiveBlockNumber(_ blockNumber: BlockNumber) {
        logger.debug("Block number: \(blockNumber)")

        currentBlock = blockNumber
    }

    func didReceivePreflight(_ preflight: SubtensorStakingPreflight) {
        logger.debug("Preflight: \(preflight)")

        self.preflight = preflight

        provideMinStakeViewModel()
    }

    func didReceiveExistentialDeposit(_ deposit: Balance) {
        logger.debug("Existential deposit: \(deposit)")

        existentialDeposit = deposit
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

extension SubtensorStakingSetupPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideAssetViewModel()
            provideAmountInputViewModel()
            provideMinStakeViewModel()
            provideFeeViewModel()
            provideDelegateViewModel()
        }
    }
}
