import Foundation
import SoraFoundation
import BigInt

final class NPoolsUnstakeConfirmPresenter: NPoolsUnstakeBasePresenter {
    weak var view: NPoolsUnstakeConfirmViewProtocol?

    var wireframe: NPoolsUnstakeConfirmWireframeProtocol? {
        baseWireframe as? NPoolsUnstakeConfirmWireframeProtocol
    }

    var interactor: NPoolsUnstakeConfirmInteractorInputProtocol? {
        baseInteractor as? NPoolsUnstakeConfirmInteractorInputProtocol
    }

    let selectedAccount: MetaChainAccountResponse
    let unstakingAmount: Decimal

    private lazy var walletViewModelFactory = WalletAccountViewModelFactory()
    private lazy var displayAddressViewModelFactory = DisplayAddressViewModelFactory()

    init(
        interactor: NPoolsUnstakeConfirmInteractorInputProtocol,
        wireframe: NPoolsUnstakeConfirmWireframeProtocol,
        unstakingAmount: Decimal,
        selectedAccount: MetaChainAccountResponse,
        chainAsset: ChainAsset,
        hintsViewModelFactory: NPoolsUnstakeHintsFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dataValidatorFactory: NominationPoolDataValidatorFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.selectedAccount = selectedAccount
        self.unstakingAmount = unstakingAmount

        super.init(
            baseInteractor: interactor,
            baseWireframe: wireframe,
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
            unstakingAmount,
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

    // MARK: Subsclass

    override func updateView() {
        provideAmountViewModel()
        provideWalletViewModel()
        provideAccountViewModel()
        provideFee()
        provideHints()
    }

    override func getInputAmount() -> Decimal? {
        unstakingAmount
    }

    override func getInputAmountInPlank() -> BigUInt? {
        unstakingAmount.toSubstrateAmount(precision: chainAsset.assetDisplayInfo.assetPrecision)
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

    override func provideHints() {
        let hints = hintsViewModelFactory.createHints(
            stakingDuration: stakingDuration,
            rewards: claimableRewards,
            locale: selectedLocale
        )

        view?.didReceiveHints(viewModel: hints)
    }

    override func didReceive(price: PriceData?) {
        super.didReceive(price: price)

        provideAmountViewModel()
        provideFee()
    }
}

extension NPoolsUnstakeConfirmPresenter: NPoolsUnstakeConfirmPresenterProtocol {
    func setup() {
        updateView()

        interactor?.setup()
    }

    func proceed() {
        let validators = getValidations()

        DataValidationRunner(
            validators: validators
        ).runValidation { [weak self] in
            guard let unstakingPoints = self?.getUnstakingPoints() else {
                return
            }

            self?.view?.didStartLoading()
            self?.interactor?.submit(unstakingPoints: unstakingPoints)
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

extension NPoolsUnstakeConfirmPresenter: NPoolsUnstakeConfirmInteractorOutputProtocol {
    func didReceive(submissionResult: Result<String, Error>) {
        logger.debug("Submission result: \(submissionResult)")

        view?.didStopLoading()

        switch submissionResult {
        case .success:
            wireframe?.presentExtrinsicSubmission(from: view, completionAction: .dismiss, locale: selectedLocale)
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
