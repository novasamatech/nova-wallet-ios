import Foundation
import Foundation_iOS

final class MythosStakingRedeemPresenter {
    weak var view: CollatorStakingRedeemViewProtocol?
    let wireframe: MythosStakingRedeemWireframeProtocol
    let interactor: MythosStakingRedeemInteractorInputProtocol

    let chainAsset: ChainAsset
    let selectedAccount: MetaChainAccountResponse
    let dataValidatingFactory: MythosStakingValidationFactoryProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let logger: LoggerProtocol

    private(set) var fee: ExtrinsicFeeProtocol?
    private(set) var balance: AssetBalance?
    private(set) var frozenBalance: MythosStakingFrozenBalance?
    private(set) var price: PriceData?
    private(set) var releaseQueue: MythosStakingPallet.ReleaseQueue?
    private(set) var currentBlock: BlockNumber?

    private lazy var walletViewModelFactory = WalletAccountViewModelFactory()
    private lazy var displayAddressViewModelFactory = DisplayAddressViewModelFactory()

    init(
        interactor: MythosStakingRedeemInteractorInputProtocol,
        wireframe: MythosStakingRedeemWireframeProtocol,
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        dataValidatingFactory: MythosStakingValidationFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.dataValidatingFactory = dataValidatingFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }
}

private extension MythosStakingRedeemPresenter {
    func isRedeemAll() -> Bool {
        guard let currentBlock, let frozenBalance else {
            return false
        }

        let allRedeemable = (releaseQueue ?? []).allSatisfy { $0.isRedeemable(at: currentBlock) }
        let noStaked = frozenBalance.staking == 0

        return allRedeemable && noStaked
    }

    func redeemableAmount() -> Decimal {
        guard let currentBlock, let releaseQueue else {
            return 0
        }

        let amountInPlank = releaseQueue
            .filter { $0.isRedeemable(at: currentBlock) }
            .reduce(Balance(0)) { $0 + $1.amount }

        return amountInPlank.decimal(assetInfo: chainAsset.assetDisplayInfo)
    }

    private func provideAmountViewModel() {
        let viewModel = balanceViewModelFactory.balanceFromPrice(
            redeemableAmount(),
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
        let viewModel: BalanceViewModelProtocol? = fee.map { fee in
            let amountDecimal = fee.amount.decimal(assetInfo: chainAsset.assetDisplayInfo)

            return balanceViewModelFactory.balanceFromPrice(
                amountDecimal,
                priceData: price
            ).value(for: selectedLocale)
        }

        view?.didReceiveFee(viewModel: viewModel)
    }

    private func presentOptions(for address: AccountAddress) {
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

    func refreshFee() {
        interactor.estimateFee()

        provideFeeViewModel()
    }

    func submitExtrinsic() {
        guard redeemableAmount() > 0 else {
            return
        }

        view?.didStartLoading()

        interactor.submit()
    }

    func applyCurrentState() {
        provideAmountViewModel()
        provideWalletViewModel()
        provideAccountViewModel()
        provideFeeViewModel()
    }
}

extension MythosStakingRedeemPresenter: CollatorStakingRedeemPresenterProtocol {
    func setup() {
        applyCurrentState()

        interactor.setup()

        refreshFee()
    }

    func selectAccount() {
        let chainFormat = chainAsset.chain.chainFormat

        guard let address = try? selectedAccount.chainAccount.accountId.toAddress(using: chainFormat) else {
            return
        }

        presentOptions(for: address)
    }

    func confirm() {
        DataValidationRunner(validators: [
            dataValidatingFactory.has(
                fee: fee,
                locale: selectedLocale,
                onError: { [weak self] in self?.refreshFee() }
            ),
            dataValidatingFactory.canPayFeeInPlank(
                balance: balance?.transferable,
                fee: fee,
                asset: chainAsset.assetDisplayInfo,
                locale: selectedLocale
            )
        ]).runValidation { [weak self] in
            self?.submitExtrinsic()
        }
    }
}

extension MythosStakingRedeemPresenter: MythosStakingRedeemInteractorOutputProtocol {
    func didReceiveAssetBalance(_ balance: AssetBalance?) {
        logger.debug("Balance: \(String(describing: balance))")

        self.balance = balance
    }

    func didReceivePrice(_ price: PriceData?) {
        logger.debug("Price: \(String(describing: price))")

        self.price = price

        provideAmountViewModel()
        provideFeeViewModel()
    }

    func didReceiveReleaseQueue(_ releaseQueue: MythosStakingPallet.ReleaseQueue?) {
        logger.debug("Release queue: \(String(describing: releaseQueue))")

        self.releaseQueue = releaseQueue

        provideAmountViewModel()
    }

    func didReceiveBlockNumber(_ blockNumber: BlockNumber) {
        logger.debug("Block number: \(blockNumber)")

        currentBlock = blockNumber

        provideAmountViewModel()
    }

    func didReceiveFrozen(_ frozenBalance: MythosStakingFrozenBalance) {
        logger.debug("Block number: \(frozenBalance)")

        self.frozenBalance = frozenBalance
    }

    func didReceiveFeeResult(_ result: Result<ExtrinsicFeeProtocol, Error>) {
        switch result {
        case let .success(fee):
            logger.debug("Fee: \(fee)")

            self.fee = fee

            provideFeeViewModel()
        case let .failure(error):
            logger.error("Fee error: \(error)")

            wireframe.presentFeeStatus(
                on: view,
                locale: selectedLocale
            ) { [weak self] in
                self?.refreshFee()
            }
        }
    }

    func didReceiveSubmissionResult(_ result: Result<ExtrinsicSubmittedModel, Error>) {
        view?.didStopLoading()

        switch result {
        case let .success(model):
            let action: ExtrinsicSubmissionPresentingAction = isRedeemAll() ? .popBaseAndDismiss : .dismiss

            wireframe.presentExtrinsicSubmission(
                from: view,
                sender: model.sender,
                completionAction: action,
                locale: selectedLocale
            )
        case let .failure(error):
            wireframe.handleExtrinsicSigningErrorPresentationElseDefault(
                error,
                view: view,
                closeAction: .dismiss,
                locale: selectedLocale,
                completionClosure: nil
            )
        }
    }
}

extension MythosStakingRedeemPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            applyCurrentState()
        }
    }
}
