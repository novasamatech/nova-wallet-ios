import Foundation
import BigInt
import Foundation_iOS
import SubstrateSdk

final class SubtensorUnstakeConfirmPresenter {
    weak var view: SubtensorStakingConfirmViewProtocol?
    let wireframe: SubtensorUnstakeConfirmWireframeProtocol
    let interactor: SubtensorUnstakeConfirmInteractorInputProtocol

    let chainAsset: ChainAsset
    let selectedAccount: MetaChainAccountResponse
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    /// TAO-denominated factory for the Nova fee row. The screen's `chainAsset`
    /// is the subnet (alpha) token, but the fee is charged in TAO, so the row is
    /// formatted with this instead. nil only if the TAO asset can't be resolved.
    let novaFeeBalanceViewModelFactory: BalanceViewModelFactoryProtocol?
    let position: SubtensorStakePosition
    let amount: Decimal
    let logger: LoggerProtocol

    private(set) var balance: AssetBalance?
    private(set) var fee: ExtrinsicFeeProtocol?
    private(set) var price: PriceData?
    /// Estimated TAO received from unstaking the input alpha amount on subnet.
    /// nil for root (1:1) and until AMM price arrives.
    private(set) var taoEstimate: Double?
    /// Nova service fee in plank (0.3% of min TAO out). Zero until reserves load or when N/A.
    private(set) var commissionAmount: BigUInt = 0
    /// True once `didReceiveCommission` has fired (reserves loaded, or N/A path).
    /// Until then we must not submit, or a fast Confirm tap would unstake fee-free.
    private(set) var commissionResolved = false
    /// Set when the user taps Confirm before the fee resolves; the submission is
    /// deferred and auto-continues from `didReceiveCommission`.
    private var pendingConfirm = false

    private lazy var walletViewModelFactory = WalletAccountViewModelFactory()
    private lazy var displayAddressViewModelFactory = DisplayAddressViewModelFactory()

    init(
        interactor: SubtensorUnstakeConfirmInteractorInputProtocol,
        wireframe: SubtensorUnstakeConfirmWireframeProtocol,
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        novaFeeBalanceViewModelFactory: BalanceViewModelFactoryProtocol?,
        position: SubtensorStakePosition,
        amount: Decimal,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.balanceViewModelFactory = balanceViewModelFactory
        self.novaFeeBalanceViewModelFactory = novaFeeBalanceViewModelFactory
        self.position = position
        self.amount = amount
        self.logger = logger
        self.localizationManager = localizationManager
    }

    // MARK: - View model providers

    private func provideAmountViewModel() {
        let viewModel = balanceViewModelFactory.balanceFromPrice(
            amount,
            priceData: price
        ).value(for: selectedLocale)

        view?.didReceiveAmount(viewModel: viewModel)
    }

    private func provideWalletViewModel() {
        do {
            let viewModel = try walletViewModelFactory.createDisplayViewModel(from: selectedAccount)
            view?.didReceiveWallet(viewModel: viewModel)
        } catch {
            logger.error("Did receive error: \(error)")
        }
    }

    private func provideAccountViewModel() {
        do {
            let viewModel = try walletViewModelFactory.createViewModel(from: selectedAccount)
            view?.didReceiveAccount(viewModel: viewModel.rawDisplayAddress())
        } catch {
            logger.error("Did receive error: \(error)")
        }
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

    private func provideNovaFeeViewModel() {
        // The fee is charged in TAO (0.3% of the TAO received), but this screen's
        // chainAsset is the subnet (alpha) token — so format with the TAO factory
        // and TAO precision, not the alpha asset, or the row would show the wrong
        // symbol. Fiat (priceData) is omitted here; the alpha screen doesn't carry
        // the TAO price.
        let taoAsset = chainAsset.subtensorTaoAsset()
        let precision = taoAsset?.assetDisplayInfo.assetPrecision
            ?? chainAsset.assetDisplayInfo.assetPrecision
        let factory = novaFeeBalanceViewModelFactory ?? balanceViewModelFactory

        guard commissionAmount > 0,
              let feeDecimal = Decimal.fromSubstrateAmount(
                  commissionAmount,
                  precision: precision
              ) else {
            view?.didReceiveNovaFee(viewModel: nil)
            return
        }

        let viewModel = factory.balanceFromPrice(
            feeDecimal,
            priceData: nil
        ).value(for: selectedLocale)

        view?.didReceiveNovaFee(viewModel: viewModel)
    }

    private func provideNovaFeeDisclaimer() {
        // "Includes 0.3% Nova Wallet fee." caption — shown whenever the fee applies
        // (subnet with a fee address set), independent of the typed amount.
        let feeApplies = position.netuid != SubtensorStakingConstants.rootNetuid
            && SubtensorStakingConstants.novaFeeAccountId != nil
        view?.didReceiveNovaFeeDisclaimer(visible: feeApplies)
    }

    private func provideValidatorViewModel() {
        let address = (try? position.hotkey.toAddress(using: chainAsset.chain.chainFormat))
            ?? position.hotkey.toHex()
        let displayName = position.validatorIdentity

        let icon = try? PolkadotIconGenerator().generateFromAccountId(position.hotkey)
        let imageViewModel: ImageViewModelProtocol? = icon.map { DrawableIconViewModel(icon: $0) }

        let viewModel = DisplayAddressViewModel(
            address: address,
            name: displayName,
            imageViewModel: imageViewModel
        )

        view?.didReceiveCollator(viewModel: viewModel)
    }

    private func provideHintsViewModel() {
        var hints = [
            R.string(preferredLanguages: selectedLocale.rLanguages)
                .localizable.stakingSubtensorHintNoUnbonding()
        ]

        if let taoEstimate, position.netuid != SubtensorStakingConstants.rootNetuid {
            let formatted = String(format: "%.4f", taoEstimate)
            hints.append(R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.stakingSubtensorUnstakeTaoReceived(formatted))
        }

        view?.didReceiveHints(viewModel: hints)
    }

    private func refreshFee() {
        fee = nil
        interactor.estimateFee()
        provideFeeViewModel()
    }

    private func applyCurrentState() {
        provideAmountViewModel()
        provideWalletViewModel()
        provideAccountViewModel()
        provideFeeViewModel()
        provideNovaFeeViewModel()
        provideNovaFeeDisclaimer()
        provideValidatorViewModel()
        provideHintsViewModel()
    }

    private func presentOptions(for address: AccountAddress) {
        guard let view = view else { return }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chainAsset.chain,
            locale: selectedLocale
        )
    }
}

// MARK: - CollatorStakingConfirmPresenterProtocol

extension SubtensorUnstakeConfirmPresenter: CollatorStakingConfirmPresenterProtocol {
    func setup() {
        applyCurrentState()
        interactor.setup()
        refreshFee()
    }

    func selectAccount() {
        guard let address = try? selectedAccount.chainAccount.accountId.toAddress(
            using: chainAsset.chain.chainFormat
        ) else {
            return
        }

        presentOptions(for: address)
    }

    func selectCollator() {
        guard let address = try? position.hotkey.toAddress(
            using: chainAsset.chain.chainFormat
        ) else {
            return
        }

        presentOptions(for: address)
    }

    func confirm() {
        // Unstake amount is taken from this user-typed value (alpha for subnet,
        // TAO for root). Cap at the position size; the chain enforces the
        // same bound but failing fast here gives a better UX.
        let positionAmount = position.amount
        guard let amountInPlank = amount.toSubstrateAmount(
            precision: chainAsset.assetDisplayInfo.assetPrecision
        ) else {
            return
        }

        guard amountInPlank <= positionAmount else {
            if let view = view {
                wireframe.presentAmountTooHigh(from: view, locale: selectedLocale)
            }
            return
        }

        view?.didStartLoading()

        // The unstake fee is computed asynchronously once AMM reserves load. If the
        // user confirms before that, defer submission so we never unstake fee-free;
        // didReceiveCommission resumes it. Dust (fee floors to 0) still resolves the
        // flag, so a genuinely-zero fee proceeds correctly.
        let feeApplies = position.netuid != SubtensorStakingConstants.rootNetuid
            && SubtensorStakingConstants.novaFeeAccountId != nil
        if feeApplies, !commissionResolved {
            pendingConfirm = true
            return
        }

        interactor.confirm()
    }
}

// MARK: - SubtensorUnstakeConfirmInteractorOutputProtocol

extension SubtensorUnstakeConfirmPresenter: SubtensorUnstakeConfirmInteractorOutputProtocol {
    func didReceiveAssetBalance(_ balance: AssetBalance?) {
        self.balance = balance
    }

    func didReceivePrice(_ priceData: PriceData?) {
        price = priceData

        provideAmountViewModel()
        provideFeeViewModel()
        provideNovaFeeViewModel()
    }

    func didReceiveFee(_ result: Result<ExtrinsicFeeProtocol, Error>) {
        switch result {
        case let .success(feeInfo):
            fee = feeInfo
            provideFeeViewModel()
        case let .failure(error):
            logger.error("Did receive fee error: \(error)")

            wireframe.presentFeeStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.refreshFee()
            }
        }
    }

    func didCompleteExtrinsicSubmission(for result: Result<ExtrinsicSubmittedModel, Error>) {
        view?.didStopLoading()

        switch result {
        case let .success(model):
            wireframe.complete(
                on: view,
                sender: model.sender,
                locale: selectedLocale
            )
        case let .failure(error):
            applyCurrentState()
            refreshFee()

            wireframe.handleExtrinsicSigningErrorPresentationElseDefault(
                error,
                view: view,
                closeAction: .dismiss,
                locale: selectedLocale,
                completionClosure: nil
            )
        }
    }

    func didReceiveCommission(_ amount: BigUInt) {
        commissionAmount = amount
        commissionResolved = true
        provideNovaFeeViewModel()

        // Resume a confirm that was deferred while the fee was still resolving.
        if pendingConfirm {
            pendingConfirm = false
            interactor.confirm()
        }
    }

    func didReceiveAMMPrice(spotPrice: Double?, taoReserve _: UInt64, alphaInReserve _: UInt64) {
        if let spotPrice, spotPrice > 0 {
            // tao_received ≈ alpha_amount * spot_price (TAO per alpha)
            let alphaAmount = NSDecimalNumber(decimal: amount).doubleValue
            taoEstimate = alphaAmount * spotPrice
        }

        provideHintsViewModel()

        if !interactor.hasPendingExtrinsic {
            refreshFee()
        }
    }

    func didReceiveError(_ error: Error) {
        logger.error("Did receive error: \(error)")

        // Release a deferred confirm's loading state so the user isn't left
        // spinning if the AMM reserve fetch (which resolves the fee) failed.
        if pendingConfirm {
            pendingConfirm = false
            view?.didStopLoading()
        }

        if let view = view {
            _ = wireframe.present(
                error: error,
                from: view,
                locale: selectedLocale
            )
        }
    }
}

// MARK: - Localizable

extension SubtensorUnstakeConfirmPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideAmountViewModel()
            provideFeeViewModel()
            provideNovaFeeViewModel()
            provideHintsViewModel()
        }
    }
}
