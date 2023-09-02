import Foundation
import SoraFoundation
import BigInt

final class NominationPoolBondMoreConfirmPresenter: NominationPoolBondMoreBasePresenter {
    weak var view: NominationPoolBondMoreConfirmViewProtocol? {
        baseView as? NominationPoolBondMoreConfirmViewProtocol
    }

    var wireframe: NominationPoolBondMoreConfirmWireframeProtocol? {
        baseWireframe as? NominationPoolBondMoreConfirmWireframeProtocol
    }

    var interactor: NominationPoolBondMoreConfirmInteractorInputProtocol? {
        baseInteractor as? NominationPoolBondMoreConfirmInteractorInputProtocol
    }

    let selectedAccount: MetaChainAccountResponse
    let amount: Decimal

    private lazy var walletViewModelFactory = WalletAccountViewModelFactory()
    private lazy var displayAddressViewModelFactory = DisplayAddressViewModelFactory()

    init(
        interactor: NominationPoolBondMoreConfirmInteractorInputProtocol,
        wireframe: NominationPoolBondMoreConfirmWireframeProtocol,
        amount: Decimal,
        selectedAccount: MetaChainAccountResponse,
        chainAsset: ChainAsset,
        hintsViewModelFactory: NominationPoolsBondMoreHintsFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dataValidatorFactory: NominationPoolDataValidatorFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.selectedAccount = selectedAccount
        self.amount = amount
        super.init(
            interactor: interactor,
            wireframe: wireframe,
            chainAsset: chainAsset,
            hintsViewModelFactory: hintsViewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatorFactory: dataValidatorFactory,
            localizationManager: localizationManager,
            logger: logger
        )
    }

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

    override func updateView() {
        provideAmountViewModel()
        provideWalletViewModel()
        provideAccountViewModel()
        provideFee()
        provideHints()
    }

    override func provideFee() {
        let viewModel: BalanceViewModelProtocol? = fee.flatMap { amount in
            guard let amountDecimal = Decimal.fromSubstrateAmount(
                amount,
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

    override func getInputAmount() -> Decimal? {
        amount
    }

    override func getInputAmountInPlank() -> BigUInt? {
        amount.toSubstrateAmount(precision: chainAsset.assetDisplayInfo.assetPrecision)
    }

    override func didReceive(price: PriceData?) {
        super.didReceive(price: price)

        provideAmountViewModel()
        provideFee()
    }
}

extension NominationPoolBondMoreConfirmPresenter: NominationPoolBondMoreConfirmPresenterProtocol {
    func setup() {
        refreshFee()
        updateView()
        interactor?.setup()
    }

    func proceed() {
        let validators = getValidations()

        DataValidationRunner(
            validators: validators
        ).runValidation { [weak self] in
            guard let amount = self?.getInputAmountInPlank() else {
                return
            }

            self?.view?.didStartLoading()
            self?.interactor?.submit(amount: amount)
        }
    }

    func selectAccount() {
        guard
            let address = selectedAccount.chainAccount.toAddress(),
            let view = view else {
            return
        }

        wireframe?.presentAccountOptions(
            from: view,
            address: address,
            chain: chainAsset.chain,
            locale: selectedLocale
        )
    }
}

extension NominationPoolBondMoreConfirmPresenter: NominationPoolBondMoreConfirmInteractorOutputProtocol {
    func didReceive(submissionResult: SubmitExtrinsicResult) {
        view?.didStopLoading()

        switch submissionResult {
        case .success:
            wireframe?.presentExtrinsicSubmission(from: view, completionAction: .dismiss, locale: selectedLocale)
        case let .failure(error):
            if error.isWatchOnlySigning {
                wireframe?.presentDismissingNoSigningView(from: view)
            } else {
                _ = wireframe?.present(error: error, from: view, locale: selectedLocale)
            }
        }
    }
}
