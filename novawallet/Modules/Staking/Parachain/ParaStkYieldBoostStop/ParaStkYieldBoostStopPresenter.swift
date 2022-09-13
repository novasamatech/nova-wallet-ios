import Foundation
import BigInt
import SoraFoundation

final class ParaStkYieldBoostStopPresenter {
    weak var view: ParaStkYieldBoostStopViewProtocol?
    let wireframe: ParaStkYieldBoostStopWireframeProtocol
    let interactor: ParaStkYieldBoostStopInteractorInputProtocol

    let chainAsset: ChainAsset
    let selectedAccount: MetaChainAccountResponse
    let dataValidatingFactory: ParaStkYieldBoostValidatorFactoryProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let logger: LoggerProtocol
    let collatorId: AccountId
    let collatorIdentity: AccountIdentity?

    private(set) var yieldBoostTasks: [ParaStkYieldBoostState.Task]?
    private(set) var extrinsicFee: BigUInt?
    private(set) var balance: AssetBalance?
    private(set) var price: PriceData?

    private lazy var walletDisplayViewModelFactory = WalletAccountViewModelFactory()
    private lazy var addressDisplayViewModelFactory = DisplayAddressViewModelFactory()

    init(
        interactor: ParaStkYieldBoostStopInteractorInputProtocol,
        wireframe: ParaStkYieldBoostStopWireframeProtocol,
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        collatorId: AccountId,
        collatorIdentity: AccountIdentity?,
        dataValidatingFactory: ParaStkYieldBoostValidatorFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.collatorId = collatorId
        self.collatorIdentity = collatorIdentity
        self.dataValidatingFactory = dataValidatingFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }

    func refreshFee() {
        extrinsicFee = nil

        if let taskId = yieldBoostTasks?.first(where: { $0.collatorId == collatorId })?.taskId {
            interactor.estimateCancelAutocompoundFee(for: taskId)
        }
    }

    func performSubmition() {
        if let taskId = yieldBoostTasks?.first(where: { $0.collatorId == collatorId })?.taskId {
            view?.didStartLoading()

            interactor.stopAutocompound(by: taskId)
        }
    }

    func provideWalletViewModel() {
        guard let viewModel = try? walletDisplayViewModelFactory.createDisplayViewModel(from: selectedAccount) else {
            return
        }

        view?.didReceiveWallet(viewModel: viewModel.cellViewModel)
    }

    private func provideAccountViewModel() {
        guard let address = selectedAccount.chainAccount.toAddress() else {
            return
        }

        let viewModel = addressDisplayViewModelFactory.createViewModel(from: address)
        view?.didReceiveSender(viewModel: viewModel)
    }

    private func provideCollatorViewModel() {
        guard let address = try? collatorId.toAddress(using: chainAsset.chain.chainFormat) else {
            return
        }

        let displayAddress = DisplayAddress(
            address: address,
            username: collatorIdentity?.displayName ?? ""
        )

        let viewModel = addressDisplayViewModelFactory.createViewModel(from: displayAddress)
        view?.didReceiveCollator(viewModel: viewModel)
    }

    private func provideNetworkFeeViewModel() {
        let assetInfo = chainAsset.assetDisplayInfo
        if let fee = extrinsicFee {
            let feeDecimal = Decimal.fromSubstrateAmount(
                fee,
                precision: assetInfo.assetPrecision
            ) ?? 0.0

            let viewModel = balanceViewModelFactory.balanceFromPrice(feeDecimal, priceData: price)
                .value(for: selectedLocale)

            view?.didReceiveNetworkFee(viewModel: viewModel)
        } else {
            view?.didReceiveNetworkFee(viewModel: nil)
        }
    }

    func updateView() {
        provideWalletViewModel()
        provideAccountViewModel()
        provideNetworkFeeViewModel()
        provideCollatorViewModel()
    }
}

extension ParaStkYieldBoostStopPresenter: ParaStkYieldBoostStopPresenterProtocol {
    func setup() {
        updateView()

        interactor.setup()

        refreshFee()
    }

    func submit() {
        let assetInfo = chainAsset.assetDisplayInfo

        DataValidationRunner(validators: [
            dataValidatingFactory.hasInPlank(
                fee: extrinsicFee,
                locale: selectedLocale,
                precision: assetInfo.assetPrecision
            ) { [weak self] in
                self?.refreshFee()
            },
            dataValidatingFactory.canPayFeeInPlank(
                balance: balance?.transferable,
                fee: extrinsicFee,
                asset: assetInfo,
                locale: selectedLocale
            ),
            dataValidatingFactory.cancellingTaskExists(
                for: collatorId,
                tasks: yieldBoostTasks,
                locale: selectedLocale
            )
        ]).runValidation { [weak self] in
            self?.performSubmition()
        }
    }

    func showSenderActions() {
        guard let view = view, let address = selectedAccount.chainAccount.toAddress() else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chainAsset.chain,
            locale: selectedLocale
        )
    }
}

extension ParaStkYieldBoostStopPresenter: ParaStkYieldBoostStopInteractorOutputProtocol {
    func didStopAutocompound(with _: String) {
        view?.didStopLoading()

        wireframe.presentExtrinsicSubmission(from: view, completionAction: .dismiss, locale: selectedLocale)
    }

    func didReceiveStopAutocompound(error: ParaStkYieldBoostStopError) {
        logger.error("Did receive interactor error: \(error)")

        switch error {
        case let .yieldBoostStopFailed(error):
            view?.didStopLoading()

            if error.isWatchOnlySigning {
                wireframe.presentDismissingNoSigningView(from: view)
            } else {
                _ = wireframe.present(error: error, from: view, locale: selectedLocale)
            }
        }
    }

    func didReceiveCancelTask(feeInfo: RuntimeDispatchInfo) {
        extrinsicFee = BigUInt(feeInfo.fee)

        provideNetworkFeeViewModel()
    }

    func didReceiveCancelInteractor(error: ParaStkYieldBoostCancelInteractorError) {
        logger.error("Did receive cancel error: \(error)")

        switch error {
        case .cancelFeeFetchFailed:
            wireframe.presentFeeStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.refreshFee()
            }
        }
    }

    func didReceiveAsset(balance: AssetBalance?) {
        self.balance = balance
    }

    func didReceiveAsset(price: PriceData?) {
        self.price = price

        provideNetworkFeeViewModel()
    }

    func didReceiveYieldBoost(tasks: [ParaStkYieldBoostState.Task]?) {
        yieldBoostTasks = tasks

        refreshFee()
    }

    func didReceiveCommonInteractor(error: ParaStkYieldBoostCommonInteractorError) {
        logger.error("Did receive common error: \(error)")

        switch error {
        case .balanceSubscriptionFailed, .priceSubscriptionFailed, .yieldBoostTasksSubscriptionFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.retryCommonSubscriptions()
            }
        }
    }
}

extension ParaStkYieldBoostStopPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideNetworkFeeViewModel()
        }
    }
}
