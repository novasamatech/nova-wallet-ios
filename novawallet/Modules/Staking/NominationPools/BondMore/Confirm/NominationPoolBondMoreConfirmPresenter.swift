import Foundation
import Foundation_iOS
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
        stakingActivity: StakingActivityForValidating,
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
            stakingActivity: stakingActivity,
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
            guard let amount = self?.getInputAmountInPlank(), let needsMigration = self?.needsMigration else {
                return
            }

            self?.view?.didStartLoading()
            self?.interactor?.submit(amount: amount, needsMigration: needsMigration)
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
        case let .success(model):
            // TODO: MS navigation
            wireframe?.presentExtrinsicSubmission(
                from: view,
                sender: model.sender,
                completionAction: .dismiss,
                locale: selectedLocale
            )
        case let .failure(error):
            wireframe?.handleExtrinsicSigningErrorPresentationElseDefault(
                error,
                view: view,
                closeAction: .dismiss,
                locale: selectedLocale,
                completionClosure: nil
            )
        }
    }
}
