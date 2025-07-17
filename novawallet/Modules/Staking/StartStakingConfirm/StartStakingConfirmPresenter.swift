import Foundation
import BigInt
import Foundation_iOS

class StartStakingConfirmPresenter {
    weak var view: StartStakingConfirmViewProtocol?
    let wireframe: StartStakingConfirmWireframeProtocol
    let interactor: StartStakingConfirmInteractorInputProtocol

    let chainAsset: ChainAsset
    let amount: Decimal
    let selectedAccount: MetaChainAccountResponse
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    let logger: LoggerProtocol

    var assetBalance: AssetBalance?
    var price: PriceData?
    var fee: ExtrinsicFeeProtocol?
    var restrictions: RelaychainStakingRestrictions?

    private lazy var walletDisplayViewModelFactory = WalletAccountViewModelFactory()
    private lazy var addressDisplayViewModelFactory = DisplayAddressViewModelFactory()

    init(
        interactor: StartStakingConfirmInteractorInputProtocol,
        wireframe: StartStakingConfirmWireframeProtocol,
        amount: Decimal,
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.amount = amount
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.balanceViewModelFactory = balanceViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }

    func provideAmountViewModel() {
        let viewModel = balanceViewModelFactory.balanceFromPrice(
            amount,
            priceData: price
        ).value(for: selectedLocale)

        view?.didReceiveAmount(viewModel: viewModel)
    }

    func provideWalletViewModel() {
        guard
            let viewModel = try? walletDisplayViewModelFactory.createDisplayViewModel(
                from: selectedAccount
            ) else {
            return
        }

        view?.didReceiveWallet(viewModel: viewModel.cellViewModel)
    }

    func provideAccountViewModel() {
        guard let address = selectedAccount.chainAccount.toAddress() else {
            return
        }

        let viewModel = addressDisplayViewModelFactory.createViewModel(from: address)
        view?.didReceiveAccount(viewModel: viewModel)
    }

    func provideFeeViewModel() {
        if let fee = fee {
            let feeDecimal = fee.amount.decimal(precision: chainAsset.asset.precision)

            let viewModel = balanceViewModelFactory.balanceFromPrice(feeDecimal, priceData: price)
                .value(for: selectedLocale)

            view?.didReceiveFee(viewModel: viewModel)
        } else {
            view?.didReceiveFee(viewModel: nil)
        }
    }

    func showDetails(for address: AccountAddress) {
        guard let view = view else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chainAsset.chain,
            locale: selectedLocale
        )
    }

    func provideStakingType() {
        fatalError("Must be overriden by subsclass")
    }

    func provideStakingDetails() {
        fatalError("Must be overriden by subsclass")
    }

    func showStakingDetails() {
        fatalError("Must be overriden by subsclass")
    }

    func stakingOption() -> SelectedStakingOption? {
        fatalError("Must be overriden by subsclass")
    }

    private func updateView() {
        provideAmountViewModel()
        provideWalletViewModel()
        provideAccountViewModel()
        provideFeeViewModel()
        provideStakingType()
        provideStakingDetails()
    }

    func createCommonValidations() -> [DataValidating] {
        [
            dataValidatingFactory.has(
                fee: fee,
                locale: selectedLocale
            ) { [weak self] in
                self?.interactor.estimateFee()
            },
            dataValidatingFactory.canPayFeeInPlank(
                balance: assetBalance?.transferable,
                fee: fee,
                asset: chainAsset.assetDisplayInfo,
                locale: selectedLocale
            ),
            dataValidatingFactory.canNominateInPlank(
                amount: amount,
                minimalBalance: restrictions?.minJoinStake,
                minNominatorBond: restrictions?.minJoinStake,
                precision: chainAsset.asset.precision,
                locale: selectedLocale
            ),
            dataValidatingFactory.allowsNewNominators(
                flag: restrictions?.allowsNewStakers ?? true,
                staking: stakingOption(),
                locale: selectedLocale
            )
        ]
    }

    func createStakingSpecificValidations() -> [DataValidating] {
        fatalError("Must be overriden by subsclass")
    }

    func createValidations() -> [DataValidating] {
        createCommonValidations() + createStakingSpecificValidations()
    }
}

extension StartStakingConfirmPresenter: StartStakingConfirmPresenterProtocol {
    func setup() {
        updateView()

        interactor.setup()
    }

    func selectSender() {
        if
            let address = try? selectedAccount.chainAccount.accountId.toAddress(
                using: chainAsset.chain.chainFormat
            ) {
            showDetails(for: address)
        }
    }

    func selectStakingDetails() {
        showStakingDetails()
    }

    func confirm() {
        let validations = createValidations()

        DataValidationRunner(validators: validations).runValidation { [weak self] in
            self?.view?.didStartLoading()
            self?.interactor.submit()
        }
    }
}

extension StartStakingConfirmPresenter: StartStakingConfirmInteractorOutputProtocol {
    func didReceive(assetBalance: AssetBalance?) {
        self.assetBalance = assetBalance
    }

    func didReceive(price: PriceData?) {
        self.price = price

        provideAmountViewModel()
        provideFeeViewModel()
    }

    func didReceive(fee: ExtrinsicFeeProtocol) {
        self.fee = fee

        logger.debug("Did receive fee: \(fee)")

        provideFeeViewModel()
    }

    func didReceiveConfirmation(model _: ExtrinsicSubmittedModel) {
        view?.didStopLoading()

        wireframe.presentExtrinsicSubmission(from: view, completionAction: .popBaseAndDismiss, locale: selectedLocale)
    }

    func didReceive(restrictions: RelaychainStakingRestrictions) {
        self.restrictions = restrictions

        logger.debug("Did receive restrinctions: \(restrictions)")
    }

    func didReceive(error: StartStakingConfirmInteractorError) {
        logger.error("Did receive error: \(error)")

        switch error {
        case .assetBalance, .price:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.remakeSubscriptions()
            }
        case .restrictions:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.retryRestrinctions()
            }
        case .fee:
            wireframe.presentFeeStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.estimateFee()
            }
        case let .confirmation(internalError):
            view?.didStopLoading()

            wireframe.handleExtrinsicSigningErrorPresentationElseDefault(
                internalError,
                view: view,
                closeAction: .dismiss,
                locale: selectedLocale,
                completionClosure: nil
            )
        }
    }
}

extension StartStakingConfirmPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
