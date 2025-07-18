import Foundation
import Foundation_iOS
import BigInt

final class ParaStkUnstakeConfirmPresenter {
    weak var view: CollatorStkUnstakeConfirmViewProtocol?
    let wireframe: ParaStkUnstakeConfirmWireframeProtocol
    let interactor: ParaStkUnstakeConfirmInteractorInputProtocol

    let chainAsset: ChainAsset
    let selectedAccount: MetaChainAccountResponse
    let selectedCollator: DisplayAddress
    let callWrapper: UnstakeCallWrapper
    let dataValidatingFactory: ParaStkValidatorFactoryProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let hintViewModelFactory: CollatorStakingHintsViewModelFactoryProtocol
    let logger: LoggerProtocol

    private(set) var fee: ExtrinsicFeeProtocol?
    private(set) var balance: AssetBalance?
    private(set) var price: PriceData?
    private(set) var delegator: ParachainStaking.Delegator?
    private(set) var delegationsDict: [AccountId: ParachainStaking.Bond]?
    private(set) var scheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?
    private(set) var stakingDuration: ParachainStakingDuration?

    private lazy var walletViewModelFactory = WalletAccountViewModelFactory()
    private lazy var displayAddressViewModelFactory = DisplayAddressViewModelFactory()

    init(
        interactor: ParaStkUnstakeConfirmInteractorInputProtocol,
        wireframe: ParaStkUnstakeConfirmWireframeProtocol,
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        selectedCollator: DisplayAddress,
        callWrapper: UnstakeCallWrapper,
        dataValidatingFactory: ParaStkValidatorFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        hintViewModelFactory: CollatorStakingHintsViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.selectedCollator = selectedCollator
        self.callWrapper = callWrapper
        self.dataValidatingFactory = dataValidatingFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.hintViewModelFactory = hintViewModelFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func unstakingAmount() -> Decimal {
        let precision = chainAsset.assetDisplayInfo.assetPrecision

        let unstakingAmountInPlank: BigUInt

        switch callWrapper.action {
        case let .bondLess(amount):
            unstakingAmountInPlank = amount
        case let .revoke(amount):
            unstakingAmountInPlank = delegationsDict?[callWrapper.collator]?.amount ?? amount
        }

        return Decimal.fromSubstrateAmount(unstakingAmountInPlank, precision: precision) ?? 0
    }

    private func provideAmountViewModel() {
        let viewModel = balanceViewModelFactory.balanceFromPrice(
            unstakingAmount(),
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
        let viewModel: BalanceViewModelProtocol? = fee.flatMap { value in
            guard let amountDecimal = Decimal.fromSubstrateAmount(
                value.amount,
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
        let viewModel = displayAddressViewModelFactory.createViewModel(from: selectedCollator)
        view?.didReceiveCollator(viewModel: viewModel)
    }

    private func provideHintsViewModel() {
        var hints: [String] = []

        if let stakingDuration = stakingDuration {
            let durationHint = hintViewModelFactory.unstakeHintForParachainDuration(
                stakingDuration,
                locale: selectedLocale
            )

            hints.append(durationHint)
        }

        hints.append(hintViewModelFactory.unstakingRewards(for: selectedLocale))
        hints.append(hintViewModelFactory.unstakingRedeem(for: selectedLocale))

        view?.didReceiveHints(viewModel: hints)
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
        fee = nil

        interactor.estimateFee(for: callWrapper)

        provideFeeViewModel()
    }

    func submitExtrinsic() {
        view?.didStartLoading()

        interactor.confirm(for: callWrapper)
    }

    func applyCurrentState() {
        provideAmountViewModel()
        provideWalletViewModel()
        provideAccountViewModel()
        provideCollatorViewModel()
        provideHintsViewModel()
    }
}

extension ParaStkUnstakeConfirmPresenter: CollatorStkUnstakeConfirmPresenterProtocol {
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

    func selectCollator() {
        presentOptions(for: selectedCollator.address)
    }

    func confirm() {
        let assetInfo = chainAsset.assetDisplayInfo
        let collatorId = callWrapper.collator
        let stakedAmount = delegationsDict?[collatorId]?.amount

        DataValidationRunner(validators: [
            dataValidatingFactory.has(
                fee: fee,
                locale: selectedLocale,
                onError: { [weak self] in self?.refreshFee() }
            ),
            dataValidatingFactory.canPayFeeInPlank(
                balance: balance?.transferable,
                fee: fee,
                asset: assetInfo,
                locale: selectedLocale
            ),
            dataValidatingFactory.canUnstake(
                amount: unstakingAmount(),
                staked: stakedAmount,
                from: collatorId,
                scheduledRequests: scheduledRequests,
                locale: selectedLocale
            )
        ]).runValidation { [weak self] in
            self?.submitExtrinsic()
        }
    }
}

extension ParaStkUnstakeConfirmPresenter: ParaStkUnstakeConfirmInteractorOutputProtocol {
    func didCompleteExtrinsicSubmission(for result: Result<ExtrinsicSubmittedModel, Error>) {
        view?.didStopLoading()

        switch result {
        case let .success(model):
            wireframe.presentExtrinsicSubmission(
                from: view,
                sender: model.sender,
                completionAction: .dismiss,
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

    func didReceiveFee(_ result: Result<ExtrinsicFeeProtocol, Error>) {
        switch result {
        case let .success(feeInfo):
            fee = feeInfo

            provideFeeViewModel()
        case let .failure(error):
            logger.error("Did receive error: \(error)")

            wireframe.presentFeeStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.refreshFee()
            }
        }
    }

    func didReceiveDelegator(_ delegator: ParachainStaking.Delegator?) {
        self.delegator = delegator
        delegationsDict = delegator?.delegationsDict()

        if !interactor.hasPendingExtrinsic {
            provideAmountViewModel()
        }
    }

    func didReceiveScheduledRequests(_ scheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?) {
        self.scheduledRequests = scheduledRequests ?? []
    }

    func didReceiveStakingDuration(_ stakingDuration: ParachainStakingDuration) {
        self.stakingDuration = stakingDuration

        provideHintsViewModel()
    }

    func didReceiveError(_ error: Error) {
        _ = wireframe.present(error: error, from: view, locale: selectedLocale)

        logger.error("Did receive error: \(error)")
    }
}

extension ParaStkUnstakeConfirmPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideAmountViewModel()
            provideFeeViewModel()
            provideHintsViewModel()
        }
    }
}
