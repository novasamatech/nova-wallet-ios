import Foundation
import Foundation_iOS
import BigInt
import SubstrateSdk

/// Presenter for the Subtensor stake setup screen. Owns:
///   - validator selection state
///   - amount input state (typed by user / Max button / accessory)
///   - cached fetched validators (used to populate the picker without a refetch)
///   - cached min-delegation runtime constant
///   - live `AssetBalance` + `PriceData` + extrinsic `fee` from the interactor
///
/// Binding uses Nova's `BalanceViewModelFactory` so the flow lines up with
/// parachain / Mythos staking. Max / percentage buttons are wired via
/// `AmountInputResult` so they can target a rate (e.g. 1.0) regardless of
/// the current absolute amount. Fee re-estimates whenever validator or
/// amount changes (matching the Confirm flow's pattern).
final class SubtensorStakeSetupPresenter {
    weak var view: SubtensorStakeSetupViewProtocol?
    let interactor: SubtensorStakeSetupInteractorInputProtocol
    let wireframe: SubtensorStakeSetupWireframeProtocol

    let chainAsset: ChainAsset
    let netuid: UInt16
    let walletName: String
    let validatorProvider: SubtensorValidatorProvider
    let cellViewModelFactory: SubtensorValidatorCellViewModelFactory
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let localizationManager: LocalizationManagerProtocol

    private var validators: [SubtensorValidator] = []
    private var minDelegationRao: BigUInt?
    private var selectedValidator: SubtensorValidator?

    private var assetBalance: AssetBalance?
    private var price: PriceData?
    private var fee: ExtrinsicFeeProtocol?
    private var inputResult: AmountInputResult?

    init(
        interactor: SubtensorStakeSetupInteractorInputProtocol,
        wireframe: SubtensorStakeSetupWireframeProtocol,
        chainAsset: ChainAsset,
        walletName: String,
        validatorProvider: SubtensorValidatorProvider,
        cellViewModelFactory: SubtensorValidatorCellViewModelFactory,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        netuid: UInt16 = SubtensorStakingConstants.rootNetuid
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chainAsset = chainAsset
        self.walletName = walletName
        self.validatorProvider = validatorProvider
        self.cellViewModelFactory = cellViewModelFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.localizationManager = localizationManager
        self.netuid = netuid
    }

    // MARK: - Private helpers

    private var selectedLocale: Locale {
        localizationManager.selectedLocale
    }

    private func transferableInPlank() -> BigUInt {
        assetBalance?.transferable ?? 0
    }

    private func transferableBalance() -> Decimal {
        let precision = chainAsset.assetDisplayInfo.assetPrecision
        return Decimal.fromSubstrateAmount(
            transferableInPlank(),
            precision: precision
        ) ?? 0
    }

    /// Available amount for the Max button. Currently returns the full
    /// transferable balance — does NOT subtract the estimated fee or a
    /// gas reserve. A user tapping Max + Continue can hit
    /// `InsufficientBalance` at submit if the displayed fee + gas would
    /// push the total over their balance. Switching to the equivalent
    /// of ParaStk's `balanceMinusFee()` is the right next step.
    private func availableForMax() -> Decimal {
        transferableBalance()
    }

    private func currentInputAmount() -> Decimal {
        inputResult?.absoluteValue(from: availableForMax()) ?? 0
    }

    // MARK: - View bindings

    private func provideAmountInputViewModel() {
        let inputAmount = inputResult?.absoluteValue(from: availableForMax())

        let viewModel = balanceViewModelFactory
            .createBalanceInputViewModel(inputAmount)
            .value(for: selectedLocale)

        view?.didReceiveAmount(inputViewModel: viewModel)
    }

    private func provideAssetViewModel() {
        let balanceDecimal = transferableBalance()
        let inputAmount = currentInputAmount()

        let viewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            inputAmount,
            balance: balanceDecimal,
            priceData: price
        ).value(for: selectedLocale)

        view?.didReceiveAssetBalance(viewModel: viewModel)
    }

    private func provideMinStakeViewModel() {
        let precision = chainAsset.assetDisplayInfo.assetPrecision

        let viewModel: BalanceViewModelProtocol? = minDelegationRao.flatMap { amount in
            guard let decimalAmount = Decimal.fromSubstrateAmount(
                amount,
                precision: precision
            ) else {
                return nil
            }

            return balanceViewModelFactory.balanceFromPrice(
                decimalAmount,
                priceData: price
            ).value(for: selectedLocale)
        }

        view?.didReceiveMinStake(viewModel: viewModel)
    }

    private func provideFeeViewModel() {
        let viewModel: BalanceViewModelProtocol? = fee.flatMap { fee in
            guard let amountDecimal = Decimal.fromSubstrateAmount(
                fee.amount,
                precision: chainAsset.assetDisplayInfo.assetPrecision
            ) else { return nil }
            return balanceViewModelFactory.balanceFromPrice(
                amountDecimal,
                priceData: price
            ).value(for: selectedLocale)
        }
        view?.didReceiveFee(viewModel: viewModel)
    }

    /// Live Nova Wallet service-fee preview shown beneath the network fee.
    /// Uses the exact same `novaFeeAmount(from:)` the stake extrinsic skims,
    /// so the previewed figure matches what is charged on Confirm.
    ///
    /// The row is always visible on a subnet with a fee address set: until an
    /// amount is entered it surfaces a loading spinner (nil view model), then
    /// shows the live 0.3% figure. On the root subnet, or with no fee address
    /// configured, the fee does not apply — we leave the row hidden (its layout
    /// default) by not calling the view at all.
    private func provideNovaFeeViewModel() {
        guard netuid != SubtensorStakingConstants.rootNetuid,
              SubtensorStakingConstants.novaFeeAccountId != nil else {
            return
        }

        let precision = chainAsset.assetDisplayInfo.assetPrecision
        let amountInPlank = currentInputAmount().toSubstrateAmount(precision: precision) ?? 0
        let feePlank = SubtensorStakingConstants.novaFeeAmount(from: amountInPlank)

        // Spinner only while no amount has been entered yet. Once an amount is in,
        // show the computed fee — including "0" for dust amounts where 0.3% floors
        // to zero (a clearer signal than a spinner that never resolves).
        guard amountInPlank > 0,
              let feeDecimal = Decimal.fromSubstrateAmount(feePlank, precision: precision) else {
            view?.didReceiveNovaFee(viewModel: nil)
            return
        }

        let viewModel = balanceViewModelFactory.balanceFromPrice(
            feeDecimal,
            priceData: price
        ).value(for: selectedLocale)

        view?.didReceiveNovaFee(viewModel: viewModel)
    }

    private func provideNovaFeeDisclaimer() {
        // "Includes 0.3% Nova Wallet fee." caption — shown whenever the fee applies
        // (subnet with a fee address set); the netuid is fixed for this screen.
        let feeApplies = netuid != SubtensorStakingConstants.rootNetuid
            && SubtensorStakingConstants.novaFeeAccountId != nil
        view?.didReceiveNovaFeeDisclaimer(visible: feeApplies)
    }

    private func provideValidatorViewModel() {
        guard let validator = selectedValidator else {
            view?.didReceiveValidator(viewModel: nil)
            return
        }

        let displayName = (validator.identity?.isEmpty == false) ? validator.identity : nil

        let address = (try? validator.hotkey.toAddress(using: chainAsset.chain.chainFormat))
            ?? validator.hotkey.toHex()
        let shortName = displayName ?? SubtensorValidatorCellViewModelFactory.shorten(address: address)

        let imageViewModel: ImageViewModelProtocol?
        if let icon = try? PolkadotIconGenerator().generateFromAccountId(validator.hotkey) {
            imageViewModel = DrawableIconViewModel(icon: icon)
        } else {
            imageViewModel = nil
        }

        let viewModel = AccountDetailsSelectionViewModel(
            displayAddress: DisplayAddressViewModel(
                address: address,
                name: shortName,
                imageViewModel: imageViewModel
            ),
            details: nil
        )

        view?.didReceiveValidator(viewModel: viewModel)
    }
}

// MARK: - SubtensorStakeSetupPresenterProtocol

extension SubtensorStakeSetupPresenter: SubtensorStakeSetupPresenterProtocol {
    func setup() {
        provideValidatorViewModel()
        provideAmountInputViewModel()
        provideAssetViewModel()
        provideMinStakeViewModel()
        provideFeeViewModel()
        provideNovaFeeViewModel()
        provideNovaFeeDisclaimer()

        interactor.setup()
    }

    func selectValidator() {
        wireframe.showValidatorPicker(
            from: view,
            netuid: netuid,
            prefetched: validators,
            validatorProvider: validatorProvider,
            cellViewModelFactory: cellViewModelFactory
        ) { [weak self] selected in
            self?.handleValidatorSelected(selected)
        }
    }

    func updateAmount(_ newValue: Decimal?) {
        inputResult = newValue.map { .absolute($0) }

        provideAssetViewModel()
        provideNovaFeeViewModel()
        refreshFee()
    }

    func selectAmountPercentage(_ percentage: Float) {
        inputResult = .rate(Decimal(Double(percentage)))

        provideAmountInputViewModel()
        provideAssetViewModel()
        provideNovaFeeViewModel()
        refreshFee()
    }

    func proceed() {
        guard let validator = selectedValidator else { return }

        let amount = currentInputAmount()
        guard amount > 0 else { return }

        wireframe.showConfirm(
            from: view,
            chainAsset: chainAsset,
            validator: validator,
            amount: amount
        )
    }

    // MARK: - Private handlers

    private func handleValidatorSelected(_ validator: SubtensorValidator) {
        selectedValidator = validator
        provideValidatorViewModel()
        refreshFee()
    }

    private func refreshFee() {
        let amountInPlank: BigUInt? = currentInputAmount() > 0
            ? currentInputAmount().toSubstrateAmount(
                precision: chainAsset.assetDisplayInfo.assetPrecision
            )
            : nil
        interactor.estimateFee(hotkey: selectedValidator?.hotkey, amount: amountInPlank)
    }
}

// MARK: - SubtensorStakeSetupInteractorOutputProtocol

extension SubtensorStakeSetupPresenter: SubtensorStakeSetupInteractorOutputProtocol {
    func didReceive(validators: [SubtensorValidator]) {
        self.validators = validators
    }

    func didReceive(minDelegation: BigUInt) {
        minDelegationRao = minDelegation
        provideMinStakeViewModel()
    }

    func didReceive(assetBalance: AssetBalance?) {
        self.assetBalance = assetBalance

        provideAssetViewModel()
        provideAmountInputViewModel()
        provideNovaFeeViewModel()
    }

    func didReceive(price: PriceData?) {
        self.price = price

        provideAssetViewModel()
        provideMinStakeViewModel()
        provideFeeViewModel()
        provideNovaFeeViewModel()
    }

    func didReceive(fee: ExtrinsicFeeProtocol?) {
        self.fee = fee
        provideFeeViewModel()
    }

    func didReceive(error: Error) {
        Logger.shared.error("SubtensorStakeSetup: interactor error — \(error.localizedDescription)")
        wireframe.showError(from: view, message: error.localizedDescription)
    }
}
