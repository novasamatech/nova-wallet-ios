import Foundation
import Foundation_iOS
import BigInt
import SubstrateSdk

final class SubtensorUnstakeSetupPresenter {
    weak var view: SubtensorUnstakeSetupViewProtocol?
    let interactor: SubtensorUnstakeSetupInteractorInputProtocol
    let wireframe: SubtensorUnstakeSetupWireframeProtocol

    let chainAsset: ChainAsset
    let position: SubtensorStakePosition
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let localizationManager: LocalizationManagerProtocol

    private var price: PriceData?
    private var fee: ExtrinsicFeeProtocol?
    private var inputResult: AmountInputResult?

    init(
        interactor: SubtensorUnstakeSetupInteractorInputProtocol,
        wireframe: SubtensorUnstakeSetupWireframeProtocol,
        chainAsset: ChainAsset,
        position: SubtensorStakePosition,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chainAsset = chainAsset
        self.position = position
        self.balanceViewModelFactory = balanceViewModelFactory
        self.localizationManager = localizationManager
    }

    private var selectedLocale: Locale {
        localizationManager.selectedLocale
    }

    private func positionDecimal() -> Decimal {
        let precision = chainAsset.assetDisplayInfo.assetPrecision
        return Decimal.fromSubstrateAmount(position.amount, precision: precision) ?? 0
    }

    private func availableForMax() -> Decimal {
        positionDecimal()
    }

    private func currentInputAmount() -> Decimal {
        inputResult?.absoluteValue(from: availableForMax()) ?? 0
    }

    private func provideAmountInputViewModel() {
        let inputAmount = inputResult?.absoluteValue(from: availableForMax())
        let viewModel = balanceViewModelFactory
            .createBalanceInputViewModel(inputAmount)
            .value(for: selectedLocale)
        view?.didReceiveAmount(inputViewModel: viewModel)
    }

    private func provideAssetViewModel() {
        let positionAmount = positionDecimal()
        let inputAmount = currentInputAmount()
        let viewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            inputAmount,
            balance: positionAmount,
            priceData: price
        ).value(for: selectedLocale)
        view?.didReceiveAssetBalance(viewModel: viewModel)
    }

    private func providePositionViewModel() {
        let positionAmount = positionDecimal()
        let viewModel = balanceViewModelFactory.balanceFromPrice(
            positionAmount,
            priceData: price
        ).value(for: selectedLocale)
        view?.didReceivePosition(viewModel: viewModel)
    }

    private func provideValidatorViewModel() {
        let address = (try? position.hotkey.toAddress(using: chainAsset.chain.chainFormat))
            ?? position.hotkey.toHex()

        let displayName = position.validatorIdentity ?? SubtensorValidatorCellViewModelFactory.shorten(address: address)

        let imageViewModel: ImageViewModelProtocol?
        if let icon = try? PolkadotIconGenerator().generateFromAccountId(position.hotkey) {
            imageViewModel = DrawableIconViewModel(icon: icon)
        } else {
            imageViewModel = nil
        }

        let viewModel = AccountDetailsSelectionViewModel(
            displayAddress: DisplayAddressViewModel(
                address: address,
                name: displayName,
                imageViewModel: imageViewModel
            ),
            details: nil
        )

        view?.didReceiveValidator(viewModel: viewModel)
    }

    private func provideFeeViewModel() {
        let viewModel: BalanceViewModelProtocol? = fee.flatMap { fee in
            guard let amountDecimal = Decimal.fromSubstrateAmount(
                fee.amount,
                precision: chainAsset.assetDisplayInfo.assetPrecision
            ) else {
                return nil
            }
            return balanceViewModelFactory.balanceFromPrice(
                amountDecimal,
                priceData: price
            ).value(for: selectedLocale)
        }
        view?.didReceiveFee(viewModel: viewModel)
    }

    /// Live Nova Wallet service-fee preview shown beneath the network fee.
    /// This screen is alpha-denominated (SN<netuid>), so — like the network-fee
    /// row above — the 0.3% fee is previewed in alpha terms (0.3% of the amount
    /// being unstaked). The confirmation screen shows the exact figure in TAO
    /// (0.3% of the TAO returned); both express the same 0.3% service fee.
    ///
    /// Always visible on a subnet with a fee address set: a nil view model (no
    /// amount entered yet) surfaces a loading spinner, then the live 0.3%
    /// figure. On the root subnet, or with no fee address configured, the fee
    /// does not apply — the row is left hidden (its layout default).
    private func provideNovaFeeViewModel() {
        guard position.netuid != SubtensorStakingConstants.rootNetuid,
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
        let feeApplies = position.netuid != SubtensorStakingConstants.rootNetuid
            && SubtensorStakingConstants.novaFeeAccountId != nil
        view?.didReceiveNovaFeeDisclaimer(visible: feeApplies)
    }
}

extension SubtensorUnstakeSetupPresenter: SubtensorUnstakeSetupPresenterProtocol {
    func setup() {
        provideValidatorViewModel()
        providePositionViewModel()
        provideAmountInputViewModel()
        provideAssetViewModel()
        provideFeeViewModel()
        provideNovaFeeViewModel()
        provideNovaFeeDisclaimer()

        interactor.setup()
    }

    func updateAmount(_ newValue: Decimal?) {
        inputResult = newValue.map { .absolute($0) }
        provideAssetViewModel()
        provideNovaFeeViewModel()
    }

    func selectAmountPercentage(_ percentage: Float) {
        inputResult = .rate(Decimal(Double(percentage)))
        provideAmountInputViewModel()
        provideAssetViewModel()
        provideNovaFeeViewModel()
    }

    func proceed() {
        let amount = currentInputAmount()
        guard amount > 0 else { return }

        wireframe.showConfirm(
            from: view,
            chainAsset: chainAsset,
            position: position,
            amount: amount
        )
    }
}

extension SubtensorUnstakeSetupPresenter: SubtensorUnstakeSetupInteractorOutputProtocol {
    func didReceive(price: PriceData?) {
        self.price = price
        provideAssetViewModel()
        providePositionViewModel()
        provideFeeViewModel()
        provideNovaFeeViewModel()
    }

    func didReceive(fee: ExtrinsicFeeProtocol?) {
        self.fee = fee
        provideFeeViewModel()
    }

    func didReceive(error: Error) {
        Logger.shared.error("SubtensorUnstakeSetup: interactor error — \(error.localizedDescription)")
        wireframe.showError(from: view, message: error.localizedDescription)
    }
}
