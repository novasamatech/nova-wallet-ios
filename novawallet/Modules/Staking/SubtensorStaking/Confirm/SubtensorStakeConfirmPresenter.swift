import Foundation
import BigInt
import Foundation_iOS
import SubstrateSdk

final class SubtensorStakeConfirmPresenter {
    weak var view: SubtensorStakingConfirmViewProtocol?
    let wireframe: SubtensorStakeConfirmWireframeProtocol
    let interactor: SubtensorStakeConfirmInteractorInputProtocol

    let chainAsset: ChainAsset
    let selectedAccount: MetaChainAccountResponse
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let validator: SubtensorValidator
    let amount: Decimal
    let logger: LoggerProtocol

    private(set) var balance: AssetBalance?
    private(set) var fee: ExtrinsicFeeProtocol?
    private(set) var price: PriceData?
    private(set) var alphaEstimate: Double?
    /// Nova service fee in plank. Zero until `didReceiveCommission` fires (or when fee is N/A).
    private(set) var commissionAmount: BigUInt = 0

    private lazy var walletViewModelFactory = WalletAccountViewModelFactory()
    private lazy var displayAddressViewModelFactory = DisplayAddressViewModelFactory()

    init(
        interactor: SubtensorStakeConfirmInteractorInputProtocol,
        wireframe: SubtensorStakeConfirmWireframeProtocol,
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        validator: SubtensorValidator,
        amount: Decimal,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.balanceViewModelFactory = balanceViewModelFactory
        self.validator = validator
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
        guard commissionAmount > 0,
              let feeDecimal = Decimal.fromSubstrateAmount(
                  commissionAmount,
                  precision: chainAsset.assetDisplayInfo.assetPrecision
              ) else {
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
        // (subnet with a fee address set), independent of the typed amount.
        let feeApplies = validator.netuid != SubtensorStakingConstants.rootNetuid
            && SubtensorStakingConstants.novaFeeAccountId != nil
        view?.didReceiveNovaFeeDisclaimer(visible: feeApplies)
    }

    private func provideValidatorViewModel() {
        let address = (try? validator.hotkey.toAddress(using: chainAsset.chain.chainFormat)) ?? validator.hotkey.toHex()
        let displayName = validator.identity

        let icon = try? PolkadotIconGenerator().generateFromAccountId(validator.hotkey)
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

        if let alphaEstimate, validator.netuid != SubtensorStakingConstants.rootNetuid {
            let formatted = String(format: "%.4f", alphaEstimate)
            hints.append("Estimated alpha received: ~\(formatted) α")
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

extension SubtensorStakeConfirmPresenter: CollatorStakingConfirmPresenterProtocol {
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
        guard let address = try? validator.hotkey.toAddress(
            using: chainAsset.chain.chainFormat
        ) else {
            return
        }

        presentOptions(for: address)
    }

    func confirm() {
        guard let amountInPlank = amount.toSubstrateAmount(
            precision: chainAsset.assetDisplayInfo.assetPrecision
        ) else {
            return
        }

        // No "amount ≤ fee" guard is needed: the Nova fee is
        // floor(amount * 30 / 10000), which is strictly less than the amount for
        // any positive amount (0.3% < 100%), so the staked remainder is always
        // positive and the interactor's BigUInt subtraction never underflows.

        let transferable = balance?.transferable ?? 0
        let feeAmount = fee?.amount ?? 0

        guard amountInPlank + feeAmount <= transferable else {
            if let view = view {
                wireframe.presentAmountTooHigh(
                    from: view,
                    locale: selectedLocale
                )
            }
            return
        }

        view?.didStartLoading()
        interactor.confirm()
    }
}

// MARK: - SubtensorStakeConfirmInteractorOutputProtocol

extension SubtensorStakeConfirmPresenter: SubtensorStakeConfirmInteractorOutputProtocol {
    func didReceiveAssetBalance(_ balance: AssetBalance?) {
        self.balance = balance
    }

    func didReceivePrice(_ priceData: PriceData?) {
        price = priceData

        provideAmountViewModel()
        provideFeeViewModel()
        provideNovaFeeViewModel()
    }

    func didReceiveCommission(_ amount: BigUInt) {
        commissionAmount = amount
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

    func didReceiveAMMPrice(spotPrice: Double?, taoReserve _: UInt64, alphaInReserve _: UInt64) {
        if let spotPrice, spotPrice > 0 {
            // alpha_received ≈ tao_amount / spot_price = tao_amount * (alphaIn / subnetTAO)
            let taoAmount = NSDecimalNumber(decimal: amount).doubleValue
            alphaEstimate = taoAmount / spotPrice
        }

        provideHintsViewModel()

        // Re-estimate fee now that we have the AMM price for proper limit_price
        if !interactor.hasPendingExtrinsic {
            refreshFee()
        }
    }

    func didReceiveError(_ error: Error) {
        logger.error("Did receive error: \(error)")

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

extension SubtensorStakeConfirmPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideAmountViewModel()
            provideFeeViewModel()
            provideNovaFeeViewModel()
            provideHintsViewModel()
        }
    }
}
