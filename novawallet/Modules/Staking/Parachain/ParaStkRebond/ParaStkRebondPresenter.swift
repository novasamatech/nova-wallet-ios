import Foundation
import BigInt
import SoraFoundation

final class ParaStkRebondPresenter {
    weak var view: ParaStkRebondViewProtocol?
    let wireframe: ParaStkRebondWireframeProtocol
    let interactor: ParaStkRebondInteractorInputProtocol

    let chainAsset: ChainAsset
    let selectedAccount: MetaChainAccountResponse
    let selectedCollator: AccountId
    let dataValidatingFactory: ParaStkValidatorFactoryProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let hintViewModelFactory: ParaStkHintsViewModelFactoryProtocol
    let logger: LoggerProtocol

    private(set) var fee: BigUInt?
    private(set) var balance: AssetBalance?
    private(set) var price: PriceData?
    private(set) var scheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?
    private(set) var collatorIdentity: AccountIdentity?

    private lazy var walletViewModelFactory = WalletAccountViewModelFactory()
    private lazy var displayAddressViewModelFactory = DisplayAddressViewModelFactory()

    init(
        interactor: ParaStkRebondInteractorInputProtocol,
        wireframe: ParaStkRebondWireframeProtocol,
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        selectedCollator: AccountId,
        collatorIdentity: AccountIdentity?,
        dataValidatingFactory: ParaStkValidatorFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        hintViewModelFactory: ParaStkHintsViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.selectedCollator = selectedCollator
        self.collatorIdentity = collatorIdentity
        self.dataValidatingFactory = dataValidatingFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.hintViewModelFactory = hintViewModelFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func rebondingAmount() -> Decimal {
        guard let request = scheduledRequests?.first(where: { $0.collatorId == selectedCollator }) else {
            return 0
        }

        let precision = chainAsset.assetDisplayInfo.assetPrecision

        return Decimal.fromSubstrateAmount(request.unstakingAmount, precision: precision) ?? 0
    }

    private func provideAmountViewModel() {
        let viewModel = balanceViewModelFactory.balanceFromPrice(
            rebondingAmount(),
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

    private func provideCollatorViewModel() {
        guard let selectedAddress = try? selectedCollator.toAddress(using: chainAsset.chain.chainFormat) else {
            return
        }

        let displayAddress = DisplayAddress(address: selectedAddress, username: collatorIdentity?.displayName ?? "")
        let viewModel = displayAddressViewModelFactory.createViewModel(from: displayAddress)
        view?.didReceiveCollator(viewModel: viewModel)
    }

    private func provideHintsViewModel() {
        let hint = hintViewModelFactory.unstakingRebond(for: selectedLocale)

        view?.didReceiveHints(viewModel: [hint])
    }

    private func presentOptions(for accountId: AccountId) {
        guard let view = view, let address = try? accountId.toAddress(using: chainAsset.chain.chainFormat) else {
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
        fee = nil

        interactor.estimateFee(for: selectedCollator)

        provideFeeViewModel()
    }

    func submitExtrinsic() {
        view?.didStartLoading()

        interactor.submit(for: selectedCollator)
    }
}

extension ParaStkRebondPresenter: ParaStkRebondPresenterProtocol {
    func setup() {
        provideAmountViewModel()
        provideWalletViewModel()
        provideAccountViewModel()
        provideFeeViewModel()
        provideCollatorViewModel()
        provideHintsViewModel()

        interactor.setup()

        refreshFee()

        interactor.fetchIdentity(for: selectedCollator)
    }

    func selectAccount() {
        presentOptions(for: selectedAccount.chainAccount.accountId)
    }

    func selectCollator() {
        presentOptions(for: selectedCollator)
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
            dataValidatingFactory.canRebond(
                collator: selectedCollator,
                scheduledRequests: scheduledRequests,
                locale: selectedLocale
            )
        ]).runValidation { [weak self] in
            self?.submitExtrinsic()
        }
    }
}

extension ParaStkRebondPresenter: ParaStkRebondInteractorOutputProtocol {
    func didReceiveAssetBalance(_ balance: AssetBalance?) {
        self.balance = balance
    }

    func didReceivePrice(_ priceData: PriceData?) {
        price = priceData

        provideAmountViewModel()
        provideFeeViewModel()
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

        provideAmountViewModel()
    }

    func didReceiveCollatorIdentity(_ identity: AccountIdentity?) {
        collatorIdentity = identity

        provideCollatorViewModel()
    }

    func didCompleteExtrinsicSubmission(for result: Result<String, Error>) {
        view?.didStopLoading()

        switch result {
        case .success:
            wireframe.complete(on: view, locale: selectedLocale)
        case let .failure(error):
            _ = wireframe.present(error: error, from: view, locale: selectedLocale)

            logger.error("Extrinsic submission failed: \(error)")
        }
    }

    func didReceiveError(_ error: Error) {
        _ = wireframe.present(error: error, from: view, locale: selectedLocale)

        logger.error("Did receive error: \(error)")
    }
}

extension ParaStkRebondPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideAmountViewModel()
            provideFeeViewModel()
            provideHintsViewModel()
        }
    }
}
