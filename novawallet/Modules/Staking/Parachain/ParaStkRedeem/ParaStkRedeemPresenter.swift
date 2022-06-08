import Foundation
import BigInt
import SoraFoundation

final class ParaStkRedeemPresenter {
    weak var view: ParaStkRedeemViewProtocol?
    let wireframe: ParaStkRedeemWireframeProtocol
    let interactor: ParaStkRedeemInteractorInputProtocol

    let chainAsset: ChainAsset
    let selectedAccount: MetaChainAccountResponse
    let dataValidatingFactory: ParaStkValidatorFactoryProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let logger: LoggerProtocol

    private(set) var fee: BigUInt?
    private(set) var balance: AssetBalance?
    private(set) var price: PriceData?
    private(set) var scheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?
    private(set) var roundInfo: ParachainStaking.RoundInfo?

    private lazy var walletViewModelFactory = WalletAccountViewModelFactory()
    private lazy var displayAddressViewModelFactory = DisplayAddressViewModelFactory()

    init(
        interactor: ParaStkRedeemInteractorInputProtocol,
        wireframe: ParaStkRedeemWireframeProtocol,
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        dataValidatingFactory: ParaStkValidatorFactoryProtocol,
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

    func redeemableCollators() -> Set<AccountId>? {
        guard let roundInfo = roundInfo, let scheduledRequests = scheduledRequests else {
            return nil
        }

        let collators = scheduledRequests
            .filter { $0.isRedeemable(at: roundInfo.current) }
            .map(\.collatorId)

        return Set(collators)
    }

    func redeemableAmount() -> Decimal {
        guard let roundInfo = roundInfo, let scheduledRequests = scheduledRequests else {
            return 0
        }

        let amountInPlank = scheduledRequests
            .filter { $0.isRedeemable(at: roundInfo.current) }
            .reduce(BigUInt(0)) { $0 + $1.unstakingAmount }

        let precision = chainAsset.assetDisplayInfo.assetPrecision

        return Decimal.fromSubstrateAmount(amountInPlank, precision: precision) ?? 0
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

    private func presentOptions(for address: AccountAddress) {
        guard let view = view else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            explorers: chainAsset.chain.explorers,
            locale: selectedLocale
        )
    }

    func refreshFee() {
        guard let collators = redeemableCollators(), !collators.isEmpty else {
            return
        }

        interactor.estimateFee(for: collators)

        provideFeeViewModel()
    }

    func submitExtrinsic() {
        guard let collators = redeemableCollators(), !collators.isEmpty else {
            return
        }

        view?.didStartLoading()

        interactor.submit(for: collators)
    }

    func applyCurrentState() {
        provideAmountViewModel()
        provideWalletViewModel()
        provideAccountViewModel()
        provideFeeViewModel()
    }
}

extension ParaStkRedeemPresenter: ParaStkRedeemPresenterProtocol {
    func setup() {
        applyCurrentState()

        interactor.setup()
    }

    func selectAccount() {
        let chainFormat = chainAsset.chain.chainFormat

        guard let address = try? selectedAccount.chainAccount.accountId.toAddress(using: chainFormat) else {
            return
        }

        presentOptions(for: address)
    }

    func confirm() {
        let precision = chainAsset.assetDisplayInfo.assetPrecision

        DataValidationRunner(validators: [
            dataValidatingFactory.hasInPlank(
                fee: fee,
                locale: selectedLocale,
                precision: precision,
                onError: { [weak self] in self?.refreshFee() }
            ),
            dataValidatingFactory.canPayFeeInPlank(
                balance: balance?.transferable,
                fee: fee,
                precision: precision,
                locale: selectedLocale
            ),
            dataValidatingFactory.canRedeem(
                amount: redeemableAmount(),
                collators: redeemableCollators(),
                locale: selectedLocale
            )
        ]).runValidation { [weak self] in
            self?.submitExtrinsic()
        }
    }
}

extension ParaStkRedeemPresenter: ParaStkRedeemInteractorOutputProtocol {
    func didReceiveAssetBalance(_ balance: AssetBalance?) {
        self.balance = balance
    }

    func didReceivePrice(_ priceData: PriceData?) {
        price = priceData

        if !interactor.hasPendingExtrinsic {
            provideAmountViewModel()
            provideFeeViewModel()
        }
    }

    func didReceiveFee(_ result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(dispatchInfo):
            fee = BigUInt(dispatchInfo.fee)

            provideFeeViewModel()
        case let .failure(error):
            logger.error("Did receive error: \(error)")

            wireframe.presentFeeStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.refreshFee()
            }
        }
    }

    func didReceiveScheduledRequests(_ scheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?) {
        self.scheduledRequests = scheduledRequests

        if !interactor.hasPendingExtrinsic {
            provideAmountViewModel()
            refreshFee()
        }
    }

    func didReceiveRoundInfo(_ roundInfo: ParachainStaking.RoundInfo?) {
        self.roundInfo = roundInfo

        if !interactor.hasPendingExtrinsic {
            provideAmountViewModel()
            refreshFee()
        }
    }

    func didCompleteExtrinsicSubmission(for result: Result<String, Error>) {
        view?.didStopLoading()

        switch result {
        case .success:
            wireframe.complete(on: view, locale: selectedLocale)
        case let .failure(error):
            applyCurrentState()
            refreshFee()

            _ = wireframe.present(error: error, from: view, locale: selectedLocale)

            logger.error("Extrinsic submission failed: \(error)")
        }
    }

    func didReceiveError(_ error: Error) {
        _ = wireframe.present(error: error, from: view, locale: selectedLocale)

        logger.error("Did receive error: \(error)")
    }
}

extension ParaStkRedeemPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideAmountViewModel()
            provideFeeViewModel()
        }
    }
}
